const std = @import("std");
const c = @import("c.zig").c;
const config = @import("config.zig");
const avro = @import("zig-avro");
const k = @import("kafka.zig");
const log = std.log;
const panic = std.debug.panic;
const errors = @import("errors.zig");
const ResponseError = errors.ResponseError;

pub const Consumer = struct {
    handle: *c.rd_kafka_t,
    // I believe we can sync some state here for the broker rebalance, handshake
    // etc. Not sure, though...
    topics: [*c]c.rd_kafka_topic_partition_list_t,

    pub fn init() !Consumer {
        var cfg = try config.init();
        try cfg.set("bootstrap.servers", "kafka:9092");
        try cfg.set("auto.offset.reset", "earliest");
        try cfg.set("enable.auto.commit", "true");
        try cfg.set("group.id", "theoestnen");
        // try cfg.set("debug", "consumer");

        var buf: [512]u8 = undefined;

        const consumer = c.rd_kafka_new(c.RD_KAFKA_CONSUMER, cfg.handle, &buf, buf.len);
        if (consumer) |cons| {
            try errors.ok(
                c.rd_kafka_poll_set_consumer(cons),
            );

            return .{
                .handle = cons,
                .topics = c.rd_kafka_topic_partition_list_new(1),
            };
        }
        return error.ConsumerInit;
    }

    pub fn deinit(self: @This()) void {
        const close = c.rd_kafka_consumer_close(self.handle);
        if (close != c.RD_KAFKA_RESP_ERR_NO_ERROR) {
            @panic("WHOA WE DONE FUCKED UP!");
        }

        c.rd_kafka_topic_partition_list_destroy(self.topics);

        c.rd_kafka_destroy(self.handle);
    }

    pub fn poll(self: @This(), timeout_ms: u64) !?k.Consumer.Message {
        const msg = c.rd_kafka_consumer_poll(self.handle, @intCast(timeout_ms));
        if (msg) |_| {
            return try k.Consumer.Message.init(msg);
        }
        return null;
    }

    pub fn commit(self: @This()) !void {
        try errors.ok(
            c.rd_kafka_commit(self.handle, self.topics, 1),
        );
    }

    pub fn subscribe(self: @This()) !void {
        const topic = "rs-load-fast-event-v1";
        _ = c.rd_kafka_topic_partition_list_add(
            self.topics,
            @ptrCast(topic),
            c.RD_KAFKA_PARTITION_UA,
        );

        try errors.ok(
            c.rd_kafka_subscribe(self.handle, self.topics),
        );
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
