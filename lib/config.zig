const std = @import("std");
const c = @import("c.zig").c;
const log = std.log;
const panic = std.debug.panic;

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

pub const Config = struct {
    cHandle: *c.rd_kafka_conf_t,

    pub fn init() !@This() {
        if (c.rd_kafka_conf_new()) |h| {
            var cfg = Config{ .cHandle = h };

            try cfg.set("client.software.name", "zig-kafka");
            try cfg.set("client.software.version", "0.0.1");

            return cfg;
        }
        return error.ConfInit;
    }

    pub fn set(self: @This(), key: []const u8, value: []const u8) !void {
        if (key.len == 0) return error.UnknownConfig;
        if (value.len == 0) return error.InvalidConfig;

        var errstr: [512]u8 = undefined;

        const res: c.rd_kafka_conf_res_t = c.rd_kafka_conf_set(
            self.cHandle,
            @ptrCast(key),
            @ptrCast(value),
            &errstr,
            errstr.len,
        );

        return switch (res) {
            c.RD_KAFKA_CONF_INVALID => error.InvalidConfig,
            c.RD_KAFKA_CONF_UNKNOWN => error.UnknownConfig,
            c.RD_KAFKA_CONF_OK => return,
            else => unreachable,
        };
    }

    pub fn get(self: @This(), key: []const u8) ![]const u8 {
        var target: [512]u8 = undefined;
        var size: usize = 0;
        const res = c.rd_kafka_conf_get(
            self.cHandle,
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

    pub fn setLogLevel(self: @This(), lvl: LogLevel) !void {
        try self.set("log_level", switch (lvl) {
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

    pub fn dump(self: @This()) void {
        var count: usize = undefined;
        const arr = c.rd_kafka_conf_dump(self.cHandle, &count);
        defer c.rd_kafka_conf_dump_free(arr, count);

        log.info("Kafka Config", .{});
        var i: usize = 0;
        while (i < count) : (i += 2) {
            std.log.info("{s} => {s}", .{ arr[i], arr[i + 1] });
        }
    }
};

test "config should accept valid entries" {
    var cfg = try Config.init();
    var res = try cfg.set("bootstrap.servers", "localhost:9092");
    try std.testing.expectEqual({}, res);

    cfg = try Config.init();
    res = try cfg.set("topic.auto.offset.reset", "earliest");
    try std.testing.expectEqual({}, res);
}

test "config should reject non-valid entries" {
    var cfg = try Config.init();
    var res = cfg.set("bootstap.servers", "localhost:9092");
    try std.testing.expectError(error.UnknownConfig, res);

    cfg = try Config.init();
    res = cfg.set("topic.auto.offset.reset", "ørliest");
    try std.testing.expectError(error.InvalidConfig, res);

    cfg = try Config.init();
    res = cfg.set("", "wat");
    try std.testing.expectError(error.UnknownConfig, res);

    cfg = try Config.init();
    res = cfg.set("auto.offset.reset", "");
    try std.testing.expectError(error.InvalidConfig, res);
}

test "config should allow getting values" {
    var cfg = try Config.init();
    _ = try cfg.set("bootstrap.servers", "localhost:9092");

    const res = try cfg.get("bootstrap.servers");
    try std.testing.expectEqualStrings("localhost:9092", res);

    cfg = try Config.init();
    _ = try cfg.set("bootstrap.servers", "localhost:9092");

    try std.testing.expectError(error.UnknownConfig, cfg.get("botstrap.servers"));
}
