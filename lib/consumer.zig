const std = @import("std");
const c = @import("c.zig").c;
const Config = @import("config.zig");
const k = @import("kafka.zig");
const log = std.log;
const panic = std.debug.panic;
const errors = @import("errors.zig");
const ResponseError = errors.ResponseError;
const avro = @import("zig-avro");

pub fn Consumer(comptime T: type) type {
    return struct {
        _rk: *c.rd_kafka_t,
        _queue: ?*c.rd_kafka_queue_t,
        _topics: [*c]c.rd_kafka_topic_partition_list_t,
        schema_id: u32,

        current_message: Message = undefined,

        pub fn init(cfg: *Config, schema_id: u32) !Consumer(T) {
            var buf: [512]u8 = undefined;

            const rk = c.rd_kafka_new(c.RD_KAFKA_CONSUMER, cfg.handle, &buf, buf.len) orelse
                return error.InitializationFailed;

            try errors.ok(c.rd_kafka_poll_set_consumer(rk));

            // We default to main queue if we don't have any consumer group
            const queue = c.rd_kafka_queue_get_consumer(rk) orelse
                c.rd_kafka_queue_get_main(rk);

            // Transfer ownership of the config handle to librdkafka, as per
            // their docs.
            cfg.handle = undefined;

            return .{
                ._rk = rk,
                ._queue = queue,
                ._topics = c.rd_kafka_topic_partition_list_new(10),
                .schema_id = schema_id,
            };
        }

        pub fn deinit(self: *Consumer(T)) void {
            log.info("Cleaning up consumer dependencies", .{});
            if (self._queue) |q| {
                c.rd_kafka_queue_destroy(q);
            }

            if (self._topics != null) {
                c.rd_kafka_topic_partition_list_destroy(self._topics);
            }

            log.info("Closing consumer", .{});
            const close = c.rd_kafka_consumer_close(self._rk);
            if (close != c.RD_KAFKA_RESP_ERR_NO_ERROR) {
                @panic("WHOA WE DONE FUCKED UP!");
            }

            std.log.info("Destroying consumer handle", .{});
            c.rd_kafka_destroy(self._rk);
        }

        pub fn poll(self: *Consumer(T), timeout_ms: u64) !?Message {
            const msg = c.rd_kafka_consumer_poll(self._rk, @intCast(timeout_ms));
            try self.init_message(msg orelse return null);
            return self.current_message;
        }

        pub fn commit(self: *Consumer(T)) !void {
            try errors.ok(c.rd_kafka_commit(self._rk, self._topics, 1));
        }

        pub fn subscribe(self: *Consumer(T), topic: []const u8) !void {
            _ = c.rd_kafka_topic_partition_list_add(
                self._topics,
                @ptrCast(topic),
                c.RD_KAFKA_PARTITION_UA,
            );

            try errors.ok(c.rd_kafka_subscribe(self._rk, self._topics));
        }

        fn init_message(self: *Consumer(T), message: *c.struct_rd_kafka_message_s) !void {
            try errors.ok(message.err);

            self.current_message = .{
                .offset = message.offset,
                .partition = message.partition,
                .payload = undefined,
                .key = str(message.key, message.key_len),
                ._msg = message,
            };

            if (message.payload) |p| {
                const inbuf = str(p, message.len);
                const got_schema_id = std.mem.readInt(u32, inbuf[1..5], .big);
                if (got_schema_id != self.schema_id) {
                    std.log.info("Expected schema ID {d}, got {d}", .{ self.schema_id, got_schema_id });
                    return errors.SchemaError.UnexpectedSchemaId;
                }
                _ = try avro.Reader.read(T, &self.current_message.payload.?, inbuf[5..]);
            } else {
                // In this case we encountered a tombstone, and need to treat it as such.
                self.current_message.payload = null;
            }
        }

        fn str(v: ?*anyopaque, len: usize) []u8 {
            const bytePtr: [*c]u8 = @ptrCast(v);
            return bytePtr[0..len];
        }

        pub const Message = struct {
            offset: i64 = 0,
            partition: i32 = 0,
            payload: ?T,
            key: ?[]const u8,

            _msg: *c.struct_rd_kafka_message_s,

            pub fn deinit(self: *Message) void {
                std.log.debug("Destroying consumer message", .{});
                c.rd_kafka_message_destroy(self._msg);
            }
        };
    };
}

test "Schema ID guard" {
    var cc = Consumer(bool){ .schema_id = 1, ._queue = null, ._rk = undefined, ._topics = undefined };

    var kafka_msg = c.struct_rd_kafka_message_s{
        .payload = @ptrCast(@constCast(&[_]u8{ 0x0, 0x0, 0x0, 0x0, 0x3 })),
        .len = 9,
        .key = @ptrCast(@constCast("hello")),
        .key_len = 5,
    };

    try std.testing.expectError(errors.SchemaError.UnexpectedSchemaId, cc.init_message(&kafka_msg));
}

test "Message parse" {
    const Foo = struct {
        a: bool,
    };
    var cc = Consumer(Foo){ .schema_id = 0, ._queue = null, ._rk = undefined, ._topics = undefined };

    var kafka_msg = c.struct_rd_kafka_message_s{
        .payload = @ptrCast(@constCast(&[_]u8{ 0x0, 0x0, 0x0, 0x0, 0x0, 0x1 })),
        .len = 10,
        .key = @ptrCast(@constCast("hello")),
        .key_len = 5,
    };

    try cc.init_message(&kafka_msg);
    try std.testing.expectEqual(true, cc.current_message.payload.?.a);

    kafka_msg = c.struct_rd_kafka_message_s{
        .payload = @ptrCast(@constCast(&[_]u8{ 0x0, 0x0, 0x0, 0x0, 0x0, 0x0 })),
        .len = 10,
        .key = @ptrCast(@constCast("hello")),
        .key_len = 5,
    };

    try cc.init_message(&kafka_msg);
    try std.testing.expectEqual(false, cc.current_message.payload.?.a);

    kafka_msg = c.struct_rd_kafka_message_s{
        .payload = null,
        .len = 0,
        .key = @ptrCast(@constCast("hello")),
        .key_len = 5,
    };

    try cc.init_message(&kafka_msg);
    try std.testing.expectEqual(null, cc.current_message.payload);

    kafka_msg = c.struct_rd_kafka_message_s{
        .payload = @ptrCast(@constCast(&[_]u8{ 0x0, 0x0, 0x0, 0x0, 0x0, 0x1 })),
        .len = 10,
        .key = @ptrCast(@constCast("hello")),
        .key_len = 5,
    };

    try cc.init_message(&kafka_msg);
    try std.testing.expectEqual(true, cc.current_message.payload.?.a);
}

test {
    @import("std").testing.refAllDeclsRecursive(@This());
}
