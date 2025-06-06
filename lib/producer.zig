const std = @import("std");
const c = @import("c.zig").c;
const Config = @import("config.zig");
const log = std.log;
const panic = std.debug.panic;
const errors = @import("errors.zig");
const ResponseError = errors.ResponseError;
const Topic = @import("topic.zig");

const Producer = @This();

handle: *c.rd_kafka_t,
queue: ?*c.rd_kafka_queue_t,
buffer: [1024 * 1024]u8,
pos: usize = 0,

pub fn init(allocator: std.mem.Allocator, cfg: *Config) !Producer {
    try cfg.set(allocator, "partitioner", "murmur2");
    try cfg.set(allocator, "compression.codec", "lz4");

    var buf: [256]u8 = undefined;

    if (c.rd_kafka_new(c.RD_KAFKA_PRODUCER, cfg.handle, &buf, buf.len)) |ph| {
        cfg.handle = undefined;

        return .{
            .handle = ph,
            .queue = c.rd_kafka_queue_get_main(ph),
            .buffer = undefined,
            .pos = 0,
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

pub fn produce(self: *@This(), topic: Topic, key: []const u8) !void {
    const res = c.rd_kafka_produce(
        topic.t,
        topic.partition,
        c.RD_KAFKA_MSG_F_COPY,
        @constCast(@ptrCast(self.buffer[0..self.pos])),
        self.pos,
        @ptrCast(key),
        key.len,
        null,
    );

    switch (errors.from(res)) {
        ResponseError.NoError => {},
        ResponseError.Unknown => try errors.ok(c.rd_kafka_errno2err(res)),
        else => @panic("Undocumented error code from librdkafka found"),
    }

    self.pos = 0;
}

pub const WError = ResponseError || error{OutOfMemory} || error{};

pub const Writer = std.io.Writer(*Producer, WError, write);

pub fn writer(self: *Producer) Writer {
    return .{ .context = self };
}

pub fn write(self: *Producer, bytes: []const u8) ResponseError!usize {
    for (bytes) |b| {
        if (self.pos > 1024 * 1024) {
            return error.Fail;
        }
        self.buffer[self.pos] = b;
        self.pos += 1;
    }
    return bytes.len;
}

test "Producer Message writer" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var config = try Config.init(arena.allocator());
    var producer = try init(arena.allocator(), &config);
    defer producer.deinit();

    var wr = producer.writer();

    _ = try wr.write("hello");
    _ = try wr.write(" there");

    try std.testing.expectEqualStrings("hello there", producer.buffer[0..producer.pos]);
}

test {
    @import("std").testing.refAllDeclsRecursive(@This());
}
