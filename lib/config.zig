const std = @import("std");
const c = @import("c.zig").c;
const log = std.log;
const panic = std.debug.panic;

handle: *c.rd_kafka_conf_t,
alloc: std.mem.Allocator,

const Config = @This();

pub fn init(allocator: std.mem.Allocator) !Config {
    if (c.rd_kafka_conf_new()) |h| {
        var cfg = Config{
            .handle = h,
            .alloc = allocator,
        };

        try cfg.set(allocator, "client.software.name", "zig-kafka");
        try cfg.set(allocator, "client.software.version", "2.0.0");

        return cfg;
    }
    return error.ConfInit;
}

pub fn set(
    self: Config,
    allocator: std.mem.Allocator,
    key: []const u8,
    value: []const u8,
) !void {
    if (key.len == 0) return error.UnknownConfig;
    if (value.len == 0) return error.InvalidConfig;

    var errstr: [512]u8 = undefined;

    const k = try allocator.dupeZ(u8, key);
    const v = try allocator.dupeZ(u8, value);

    const res: c.rd_kafka_conf_res_t = c.rd_kafka_conf_set(
        self.handle,
        k,
        v,
        &errstr,
        errstr.len,
    );

    return switch (res) {
        c.RD_KAFKA_CONF_INVALID => error.InvalidConfig,
        c.RD_KAFKA_CONF_UNKNOWN => error.UnknownConfig,
        c.RD_KAFKA_CONF_OK => return,
        else => @panic("unreachable config set"),
    };
}

pub fn get(self: Config, key: []const u8) ![]const u8 {
    var target: [512]u8 = undefined;
    var size: usize = 0;
    const res = c.rd_kafka_conf_get(
        self.handle,
        @ptrCast(key),
        &target,
        &size,
    );

    if (size == 0) {
        return error.UnknownConfig;
    }

    return switch (res) {
        c.RD_KAFKA_CONF_INVALID => error.InvalidConfig,
        c.RD_KAFKA_CONF_UNKNOWN => error.UnknownConfig,
        c.RD_KAFKA_CONF_OK => {
            if (size > target.len) panic("librdkafka allocated behind the scenes - punishable by death", .{});
            return target[0 .. size - 1];
        },
        else => @panic("unreachable - but we're still here, right?"),
    };
}

pub const LogLevel = enum(u32) {
    Emerg = 0,
    Alert = 1,
    Crit = 2,
    Error = 3,
    Warning = 4,
    Notice = 5,
    Info = 6,
    Debug = 7,
};

pub fn setLogLevel(self: Config, lvl: LogLevel) !void {
    try self.set(self.alloc, "log_level", switch (lvl) {
        .Emerg => "0",
        .Alert => "1",
        .Crit => "2",
        .Error => "3",
        .Warning => "4",
        .Notice => "5",
        .Info => "6",
        .Debug => "7",
    });
}

pub fn dump(self: Config) void {
    var count: usize = undefined;
    const arr = c.rd_kafka_conf_dump(self.handle, &count);
    defer c.rd_kafka_conf_dump_free(arr, count);

    log.info("Kafka Config", .{});
    var i: usize = 0;
    while (i < count) : (i += 2) {
        std.log.info("{s} => {s}", .{ arr[i], arr[i + 1] });
    }
}

test "config should accept valid entries" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var cfg = try Config.init(arena.allocator());
    try std.testing.expectEqual(
        {},
        try cfg.set(arena.allocator(), "bootstrap.servers", "localhost:9092"),
    );

    try std.testing.expectEqual(
        {},
        try cfg.set(arena.allocator(), "topic.auto.offset.reset", "earliest"),
    );
}

test "config should reject non-valid entries" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var cfg = try Config.init(arena.allocator());
    try std.testing.expectError(
        error.UnknownConfig,
        cfg.set(arena.allocator(), "bootstap.servers", "localhost:9092"),
    );

    try std.testing.expectError(
        error.InvalidConfig,
        cfg.set(arena.allocator(), "topic.auto.offset.reset", "ørliest"),
    );

    try std.testing.expectError(
        error.UnknownConfig,
        cfg.set(arena.allocator(), "", "wat"),
    );

    try std.testing.expectError(
        error.InvalidConfig,
        cfg.set(arena.allocator(), "auto.offset.reset", ""),
    );
}

test "config should allow getting values" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var cfg = try Config.init(arena.allocator());
    _ = try cfg.set(arena.allocator(), "bootstrap.servers", "localhost:9092");

    const res = try cfg.get("bootstrap.servers");
    try std.testing.expectEqualStrings("localhost:9092", res);

    cfg = try Config.init(arena.allocator());
    _ = try cfg.set(arena.allocator(), "bootstrap.servers", "localhost:9092");

    try std.testing.expectError(error.UnknownConfig, cfg.get("botstrap.servers"));
}
