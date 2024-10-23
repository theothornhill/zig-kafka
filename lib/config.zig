const std = @import("std");
const c = @import("c.zig").c;
const log = std.log;

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

            return cfg;
        }
        return error.ConfInit;
    }

    pub fn set(self: @This(), key: []const u8, value: []const u8) !void {
        var errstr: [512]u8 = undefined;
        const c_errstr: [*c]u8 = @ptrCast(&errstr);
        var res: c.rd_kafka_conf_res_t = undefined;

        res = c.rd_kafka_conf_set(
            self.cHandle,
            @ptrCast(key),
            @ptrCast(value),
            c_errstr,
            errstr.len,
        );

        switch (res) {
            c.RD_KAFKA_CONF_INVALID => return error.InvalidConfig,
            c.RD_KAFKA_CONF_UNKNOWN => return error.UnknownConfig,
            else => return,
        }
    }

    pub fn setLogLevel(self: @This(), lvl: LogLevel) !void {
        const key = "log_level";
        try self.set(key, switch (lvl) {
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
