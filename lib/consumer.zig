const std = @import("std");
const c = @import("c.zig").c;
const config = @import("config.zig");
const avro = @import("zigavro");
const k = @import("kafka.zig");
const log = std.log;
const panic = std.debug.panic;
const errors = @import("errors.zig");
const ResponseError = errors.ResponseError;

pub const Consumer = struct {
    handle: *c.rd_kafka_t,

    pub fn init() !Consumer {
        var cfg = try config.init();
        try cfg.set("bootstrap.servers", "kafka:9092");
        try cfg.set("auto.offset.reset", "earliest");
        try cfg.set("group.id", "iairasetnaireniaresntrrisetnaairsentin");
        // try cfg.set("debug", "consumer");

        var buf: [512]u8 = undefined;

        const consumer = c.rd_kafka_new(c.RD_KAFKA_CONSUMER, cfg.handle, &buf, buf.len);
        if (consumer) |cons| {
            _ = c.rd_kafka_poll_set_consumer(cons);
            return .{ .handle = cons };
        }
        return error.ConsumerInit;
    }

    pub fn deinit(self: @This()) void {
        const close = c.rd_kafka_consumer_close(self.handle);
        if (close != c.RD_KAFKA_RESP_ERR_NO_ERROR) {
            @panic("WHOA WE DONE FUCKED UP!");
        }

        c.rd_kafka_destroy(self.handle);
    }

    pub fn poll(self: @This(), timeout_ms: u64) !?k.Consumer.Message {
        return try k.Consumer.Message.init(
            c.rd_kafka_consumer_poll(self.handle, @intCast(timeout_ms)),
        );
    }

    pub fn subscribe(self: @This()) !void {
        const topic = "rs-load-fast-event-v1";

        const topics = c.rd_kafka_topic_partition_list_new(1);
        _ = c.rd_kafka_topic_partition_list_add(topics, @ptrCast(topic), c.RD_KAFKA_PARTITION_UA);
        defer c.rd_kafka_topic_partition_list_destroy(topics);

        const res = c.rd_kafka_subscribe(self.handle, topics);
        if (res != c.RD_KAFKA_RESP_ERR_NO_ERROR) {
            std.debug.print("Failed to subscribe: {}\n", .{res});
            return error.Consume;
        }
    }
};

test "consumer" {
    var consumer = try Consumer.init();
    const err = try consumer.subscribe();
    std.debug.print("err: {}", .{err});
}

pub const Message = struct {
    msg: *c.struct_rd_kafka_message_s,

    offset: i64 = 0,
    partition: i32 = 0,
    payload: ?[]const u8,
    key: []const u8,

    pub fn init(msg: ?*c.struct_rd_kafka_message_s) !?@This() {
        if (msg) |message| {
            // If the message has succeed, we want to remove error
            // information, so that we don't have to handle errors every
            // time we access fields here, even when the message is ok.
            switch (errors.from(message.err)) {
                ResponseError.NoError => {},
                else => |e| return e,
            }

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
        c.rd_kafka_message_destroy(self.msg);
    }

    fn unpack(comptime T: type, v: ?*anyopaque, len: usize) T {
        return switch (T) {
            i32 => 56,
            []const u8 => {
                const bytePtr: [*c]const u8 = @ptrCast(v);
                return bytePtr[0..len];
            },
            else => {
                switch (@typeInfo(T)) {
                    .optional => |opt| {
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
