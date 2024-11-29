const std = @import("std");
const log = std.log;
const http = std.http;
const json = std.json;
const config = @import("config.zig");

pub const Registry = struct {
    baseUri: []const u8,
    client: http.Client,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, cfg: config.Config) !@This() {
        return .{
            .baseUri = cfg.get("schema.registry.url"),
            .client = http.Client{ .allocator = allocator },
            .allocator = allocator,
        };
    }

    pub fn allocUrl(self: *@This(), path: []const u8) ![]const u8 {
        return std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ self.baseUri, path });
    }

    test allocUrl {
        const allocator = std.testing.allocator;
        var cfg = try config.Config.init();
        cfg.set("schema.registry.url", "http://localhost:8081");
        var registry = try Registry.init(allocator, cfg);

        defer registry.deinit();
        const url = try registry.allocUrl("schemas/ids");
        defer allocator.free(url);

        try std.testing.expectEqualStrings("http://localhost:8081/schemas/ids", url);
        try std.testing.expectEqual(true, false);
    }

    pub fn deinit(self: *@This()) void {
        self.client.deinit();
    }

    pub const Schema = struct {
        schema: []const u8,

        pub fn getById(registry: *Registry, id: i32) !json.Parsed(@This()) {
            var body = std.ArrayList(u8).init(registry.allocator);
            defer body.deinit();

            var headers = http.Header{ .allocator = registry.allocator };
            defer headers.deinit();

            try headers.append("accept", "application/vnd.schemaregistry.v1+json");
            try headers.append("accept", "application/vnd.schemaregistry+json");
            try headers.append("accept", "application/json");

            const parialUrl = std.fmt.allocPrint(registry.allocator, "{s}/{d}", .{ "schemas/ids/", id });
            defer registry.allocator.free(parialUrl);
            const url = try registry.allocUrl(registry, parialUrl);
            defer registry.allocator.free(url);

            _ = try registry.client.fetch(.{
                .method = .GET,
                .location = .{ .url = url },
                .headers = headers,
                .response_storage = .{ .dynamic = &body },
            });

            return json.parseFromValue(@This(), registry.allocator, body, .{ .ignore_unknown_fields = true, .allocate = .alloc_always });
        }
    };
};
