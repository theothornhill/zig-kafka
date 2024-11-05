const std = @import("std");
const c = @import("c.zig").c;
const config = @import("config.zig");
const log = std.log;
const panic = std.debug.panic;
const errors = @import("errors.zig");
const ResponseError = errors.ResponseError;
const Topic = @import("topic.zig").Topic;

pub const Producer = struct {
    handle: *c.rd_kafka_t,
    queue: ?*c.rd_kafka_queue_t,

    pub const Message = struct {
        offset: i64 = 0,
        partition: i32 = 0,
        payload: ?[]const u8,
        key: []const u8,
        topic: Topic,

        pub fn init(topic: Topic, payload: ?[]const u8, key: []const u8) @This() {
            return .{
                .payload = payload,
                .key = key,
                .topic = topic,
            };
        }

        pub fn deinit(self: @This()) void {
            std.log.debug("Destroying producer message topic", .{});
            c.rd_kafka_topic_destroy(self.topic.t);
        }
    };

    pub fn init(cfg: *config.Config) !Producer {
        var buf: [256]u8 = undefined;

        if (c.rd_kafka_new(c.RD_KAFKA_PRODUCER, cfg.handle, &buf, buf.len)) |ph| {
            cfg.handle = undefined;

            return Producer{
                .handle = ph,
                .queue = c.rd_kafka_queue_get_main(ph),
            };
        }
        @panic("Producer handle failed initializing");
    }

    pub fn deinit(self: @This()) void {
        std.log.info("Shutting down producer", .{});
        if (self.queue) |q| {
            c.rd_kafka_queue_destroy(q);
        }

        self.flush(10000) catch |err| switch (err) {
            else => std.log.info("ERROR DEINIT", .{}),
        };
        std.log.info("Destroying producer handle", .{});
        c.rd_kafka_destroy(self.handle);
    }

    pub fn flush(self: @This(), timeout_ms: usize) !void {
        try errors.ok(
            c.rd_kafka_flush(self.handle, @intCast(timeout_ms)),
        );
    }

    fn poll(self: @This(), timeout_ms: usize) !void {
        try errors.ok(
            c.rd_kafka_poll(self.handle, @intCast(timeout_ms)),
        );
    }

    pub fn poller(self: @This(), timeout_ms: usize, healthy: *bool) !void {
        while (healthy.*) {
            std.log.debug("Producer poll", .{});
            try self.poll(timeout_ms);

            std.time.sleep(std.time.ns_per_s * 15);
        }
    }

    pub fn produce(self: @This(), message: Message) !void {
        const res = c.rd_kafka_produce(
            message.topic.t,
            message.topic.partition,
            c.RD_KAFKA_MSG_F_COPY,
            @constCast(@ptrCast(message.payload)),
            message.payload.?.len,
            @ptrCast(message.key),
            message.key.len,
            null,
        );

        switch (errors.from(res)) {
            ResponseError.NoError => {},
            ResponseError.Unknown => try errors.ok(c.rd_kafka_errno2err(res)),
            else => @panic("Undocumented error code from librdkafka found"),
        }
        try self.poll(0);
    }
};
