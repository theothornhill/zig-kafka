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
        .user = std.Uri.Component{ .raw = self.username },
        .password = std.Uri.Component{ .raw = self.password },
        .host = base_url.host,
        .port = base_url.port,
        .path = std.Uri.Component{ .percent_encoded = url_path },
        .query = base_url.query,
        .fragment = base_url.fragment,
    };
}

fn fetchSchema(self: @This(), response_storage: *std.Io.Writer, subject: []const u8, schema: []const u8) !void {
    const Schema = struct { schema: []const u8 };
    var client = std.http.Client{ .allocator = self.allocator };
    defer client.deinit();
    const url_path = try std.fmt.allocPrint(self.allocator, "/subjects/{s}/versions?normalize=true", .{subject});
    defer self.allocator.free(url_path);
    const auth_url = try self.authUrl(url_path);
    const shb = try self.allocator.alloc(u8, 1024);
    defer self.allocator.free(shb);
    var schema_json: std.Io.Writer.Allocating = .init(self.allocator);
    defer schema_json.deinit();
    var json_writer: std.json.Stringify = .{ .writer = &schema_json.writer };

    try json_writer.write(Schema{ .schema = schema });

    const result = client.fetch(.{
        .response_writer = response_storage,
        .method = std.http.Method.POST,
        .location = .{ .uri = auth_url },
        .payload = schema_json.written(),
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
