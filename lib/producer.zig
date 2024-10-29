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
    queue: *c.rd_kafka_queue_t,

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

    pub fn init(cfg: config.Config) !Producer {

        // c.rd_kafka_conf_set_events(
        //     cfg.handle,
        //     c.RD_KAFKA_EVENT_DR, // | c.RD_KAFKA_EVENT_STATS | c.RD_KAFKA_EVENT_ERROR | c.RD_KAFKA_EVENT_OAUTHBEARER_TOKEN_REFRESH,
        // );

        var buf: [256]u8 = undefined;

        return if (c.rd_kafka_new(c.RD_KAFKA_PRODUCER, cfg.handle, &buf, buf.len)) |ph|
            Producer{
                .handle = ph,
                .queue = c.rd_kafka_queue_get_main(ph).?,
            }
        else
            error.ProducerInit;
    }

    pub fn deinit(self: @This()) void {
        self.flush(10000) catch |err| switch (err) {
            else => std.debug.print("ERROR DEINIT", .{}),
        };
        // c.rd_kafka_destroy(self.handle);
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
        Producer.Message.init(
            Topic.init(producer.handle, "rs-load-fast-event-v1"),
            &val,
            &key,
        ),
    );
}
