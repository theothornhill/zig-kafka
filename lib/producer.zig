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

    pub fn init() !Producer {
        var cfg = try config.init();
        try cfg.set("bootstrap.servers", "kafka:9092");
        try cfg.set("request.required.acks", "-1");
        // try cfg.set("debug", "all");

        var buf: [512]u8 = undefined;

        const producer = c.rd_kafka_new(c.RD_KAFKA_PRODUCER, cfg.handle, &buf, buf.len);
        return if (producer) |p|
            .{ .handle = p }
        else
            error.ProducerInit;
    }

    pub fn deinit(self: @This()) void {
        self.flush(10000);
        if (flush != c.RD_KAFKA_RESP_ERR_NO_ERROR) {
            @panic("WHOA WE DONE FUCKED UP!");
        }

        c.rd_kafka_destroy(self.handle);
    }

    pub fn flush(self: @This(), timeout_ms: usize) !void {
        try errors.ok(
            c.rd_kafka_flush(self.handle, @intCast(timeout_ms)),
        );
    }

    pub fn poll(self: @This(), timeout_ms: usize) !void {
        try errors.ok(
            c.rd_kafka_poll(self.handle, @intCast(timeout_ms)),
        );
    }

    pub fn produce(self: @This(), message: Message) !void {
        _ = self;
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
    }
};

test "producer" {
    var val: [10]u8 = [_]u8{
        0,
        0,
        1 << 1,
        1, // logged: true
        0, // terrible: false
        1 << 1, // items array: len 1
        5 << 1, // items[0] = 5
        0, // end of array
        0, // onion type: the i32 thing
        0,
    };
    var key: [3]u8 = [_]u8{ 'f', 'o', 'o' };

    var producer = try Producer.init();
    _ = try producer.produce(
        Message.init(
            Topic.init(producer.handle, "rs-load-fast-event-v1"),
            &val,
            &key,
        ),
    );
}

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
};
