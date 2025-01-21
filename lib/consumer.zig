const std = @import("std");
const c = @import("c.zig").c;
const config = @import("config.zig");
const k = @import("kafka.zig");
const log = std.log;
const panic = std.debug.panic;
const errors = @import("errors.zig");
const ResponseError = errors.ResponseError;

pub const Consumer = struct {
    rk: *c.rd_kafka_t,
    queue: ?*c.rd_kafka_queue_t,
    topics: [*c]c.rd_kafka_topic_partition_list_t,

    pub const Message = struct {
        msg: *c.struct_rd_kafka_message_s,

        offset: i64 = 0,
        partition: i32 = 0,
        payload: ?[]const u8,
        key: []const u8,

        pub fn init(msg: ?*c.struct_rd_kafka_message_s) !?@This() {
            if (msg) |message| {
                try errors.ok(message.err);

                return .{
                    .offset = message.offset,
                    .partition = message.partition,
                    .payload = unpack(?[]const u8, message.payload, message.len),
                    .key = unpack([]const u8, message.key, message.key_len),
                    .msg = message,
                };
            }
            return null;
        }

        pub fn deinit(self: @This()) void {
            std.log.debug("Destroying consumer message", .{});
            c.rd_kafka_message_destroy(self.msg);
        }

        fn unpack(comptime T: type, v: ?*anyopaque, len: usize) T {
            return switch (T) {
                []const u8 => {
                    const bytePtr: [*c]const u8 = @ptrCast(v);
                    return bytePtr[0..len];
                },
                else => {
                    switch (@typeInfo(T)) {
                        .Optional => |opt| {
                            if (v) |_| {
                                return unpack(opt.child, v, len);
                            } else {
                                return null;
                            }
                        },
                        else => {},
                    }
                    @panic("Type not supported");
                },
            };
        }
    };

    pub fn init(cfg: *config.Config) !@This() {
        var buf: [512]u8 = undefined;

        if (c.rd_kafka_new(c.RD_KAFKA_CONSUMER, cfg.handle, &buf, buf.len)) |rk| {
            try errors.ok(
                c.rd_kafka_poll_set_consumer(rk),
            );

            const queue = if (c.rd_kafka_queue_get_consumer(rk)) |q|
                q
            else // We default to main queue if we don't have any consumer group
                c.rd_kafka_queue_get_main(rk);

            cfg.handle = undefined;
            return Consumer{
                .rk = rk,
                .queue = queue,
                .topics = c.rd_kafka_topic_partition_list_new(10),
            };
        }
        @panic("Consumer handle failed initializing");
    }

    pub fn deinit(self: @This()) void {
        log.info("Cleaning up consumer dependencies", .{});
        if (self.queue) |q| {
            c.rd_kafka_queue_destroy(q);
        }

        if (self.topics != null) {
            c.rd_kafka_topic_partition_list_destroy(self.topics);
        }

        log.info("Closing consumer", .{});
        const close = c.rd_kafka_consumer_close(self.rk);
        if (close != c.RD_KAFKA_RESP_ERR_NO_ERROR) {
            @panic("WHOA WE DONE FUCKED UP!");
        }

        std.log.info("Destroying consumer handle", .{});
        c.rd_kafka_destroy(self.rk);
    }

    pub fn poll(self: @This(), timeout_ms: u64) !?k.Consumer.Message {
        const msg = c.rd_kafka_consumer_poll(self.rk, @intCast(timeout_ms));
        if (msg) |_| {
            return try k.Consumer.Message.init(msg);
        }
        return null;
    }

    pub fn commit(self: @This()) !void {
        try errors.ok(
            c.rd_kafka_commit(self.rk, self.topics, 1),
        );
    }

    pub fn subscribe(self: @This(), topic: []const u8) !void {
        _ = c.rd_kafka_topic_partition_list_add(
            self.topics,
            @ptrCast(topic),
            c.RD_KAFKA_PARTITION_UA,
        );

        try errors.ok(
            c.rd_kafka_subscribe(self.rk, self.topics),
        );
    }
};
