const errors = @import("errors.zig");
const std = @import("std");

username: []const u8,
password: []const u8,
url: []const u8,
allocator: std.mem.Allocator,

fn authUrl(self: @This(), url_path: []const u8) !std.Uri {
    const base_url = try std.Uri.parse(self.url);
    return std.Uri{
        .scheme = base_url.scheme,
        .host = base_url.host,
        .port = base_url.port,
        .path = std.Uri.Component{ .percent_encoded = url_path },
        .query = base_url.query,
        .fragment = base_url.fragment,
    };
}

fn fetchSchema(self: @This(), response_storage: *std.Io.Writer, subject: []const u8, schema: []const u8) !void {
    const Schema = struct { schema: []const u8 };
    var client = std.http.Client{
        .allocator = self.allocator,
        .read_buffer_size = 1024 * 1024,
        .write_buffer_size = 1024 * 1024,
    };
    defer client.deinit();
    const url_path = try std.fmt.allocPrint(self.allocator, "/subjects/{s}/versions?normalize=true", .{subject});
    defer self.allocator.free(url_path);
    const auth_url = try self.authUrl(url_path);
    var schema_json: std.Io.Writer.Allocating = .init(self.allocator);
    defer schema_json.deinit();
    var json_writer: std.json.Stringify = .{ .writer = &schema_json.writer };

    try json_writer.write(Schema{ .schema = schema });

    const credentials = try std.fmt.allocPrint(self.allocator, "{s}:{s}", .{ self.username, self.password });
    defer self.allocator.free(credentials);
    const auth_str = try std.fmt.allocPrint(self.allocator, "Basic {b64}", .{credentials});
    defer self.allocator.free(auth_str);

    const result = @"fetch but with workaround for the issues https://github.com/ziglang/zig/issues/25015 and https://github.com/ziglang/zig/issues/25002"(&client, .{
        .response_writer = response_storage,
        .method = std.http.Method.POST,
        .location = .{ .uri = auth_url },
        .payload = schema_json.written(),
        .headers = .{ .authorization = .{ .override = auth_str } },
    }) catch |err| {
        std.log.err("error reaching {s} on {} port {}: {}", .{ url_path, auth_url.host.?, auth_url.port.?, err });
        return errors.SchemaError.RegistryUnreachable;
    };
    if (result.status != std.http.Status.ok) {
        std.log.err("response {} not 200 OK on {s} getting schema at {s}: {s}", .{
            result.status,
            subject,
            url_path,
            response_storage.buffer[0..response_storage.end],
        });
        return errors.SchemaError.RegistryAngry;
    }
}

pub fn findSchemaId(self: @This(), topic: []const u8, schema: []const u8) !u32 {
    const SchemaVersionResponse = struct { id: u32 };
    var response_storage: std.Io.Writer.Allocating = .init(self.allocator);
    try self.fetchSchema(&response_storage.writer, topic, schema);
    errdefer response_storage.deinit();
    const parsed = try std.json.parseFromSlice(
        SchemaVersionResponse,
        self.allocator,
        response_storage.written(),
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();
    return parsed.value.id;
}

fn @"fetch but with workaround for the issues https://github.com/ziglang/zig/issues/25015 and https://github.com/ziglang/zig/issues/25002"(
    client: *std.http.Client,
    options: std.http.Client.FetchOptions,
) std.http.Client.FetchError!std.http.Client.FetchResult {
    const uri = switch (options.location) {
        .url => |u| try std.Uri.parse(u),
        .uri => |u| u,
    };

    client.write_buffer_size = if (options.payload) |p| p.len else 0;
    const method: std.http.Method = options.method orelse
        if (options.payload != null) .POST else .GET;

    const redirect_behavior: std.http.Client.Request.RedirectBehavior = options.redirect_behavior orelse
        if (options.payload == null) @enumFromInt(3) else .unhandled;

    var req = try std.http.Client.request(client, method, uri, .{
        .redirect_behavior = redirect_behavior,
        .headers = options.headers,
        .extra_headers = options.extra_headers,
        .privileged_headers = options.privileged_headers,
        .keep_alive = options.keep_alive,
    });
    defer req.deinit();

    std.log.info("URL: {f}", .{req.uri});

    if (options.payload) |payload| {
        req.transfer_encoding = .{ .content_length = payload.len };
        var body = try req.sendBodyUnflushed(&.{});
        try body.writer.writeAll(payload);
        try body.end();
        try req.connection.?.flush();
    } else {
        try req.sendBodiless();
    }

    const redirect_buffer: []u8 = if (redirect_behavior == .unhandled) &.{} else options.redirect_buffer orelse
        try client.allocator.alloc(u8, 8 * 1024);
    defer if (options.redirect_buffer == null) client.allocator.free(redirect_buffer);

    var response = try req.receiveHead(redirect_buffer);

    const response_writer = options.response_writer orelse {
        const reader = response.reader(&.{});
        _ = reader.discardRemaining() catch |err| switch (err) {
            error.ReadFailed => return response.bodyErr().?,
        };
        return .{ .status = response.head.status };
    };

    const decompress_buffer: []u8 = switch (response.head.content_encoding) {
        .identity => &.{},
        .zstd => options.decompress_buffer orelse try client.allocator.alloc(u8, std.compress.zstd.default_window_len),
        .deflate, .gzip => options.decompress_buffer orelse try client.allocator.alloc(u8, std.compress.flate.max_window_len),
        .compress => return error.UnsupportedCompressionMethod,
    };
    defer if (options.decompress_buffer == null) client.allocator.free(decompress_buffer);

    var transfer_buffer: [64]u8 = undefined;
    var decompress: std.http.Decompress = undefined;
    const reader = response.readerDecompressing(&transfer_buffer, &decompress, decompress_buffer);

    _ = reader.streamRemaining(response_writer) catch |err| switch (err) {
        error.ReadFailed => return response.bodyErr().?,
        else => |e| return e,
    };

    return .{ .status = response.head.status };
}
