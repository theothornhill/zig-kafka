const std = @import("std");
const c = @import("c.zig").c;
const Config = @import("config.zig");
const log = std.log;
const panic = std.debug.panic;
const errors = @import("errors.zig");
const ResponseError = errors.ResponseError;
const Topic = @import("topic.zig");
const avro = @import("zig-avro");
const Producer = @This();

handle: *c.rd_kafka_t,
queue: ?*c.rd_kafka_queue_t,
buffer: std.ArrayList(u8),
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator, cfg: *Config) !Producer {
    try cfg.set(allocator, "partitioner", "murmur2");
    try cfg.set(allocator, "compression.codec", "lz4");

    var buf: [256]u8 = undefined;

    if (c.rd_kafka_new(c.RD_KAFKA_PRODUCER, cfg.handle, &buf, buf.len)) |ph| {
        cfg.handle = undefined;

        return .{
            .allocator = allocator,
            .handle = ph,
            .queue = c.rd_kafka_queue_get_main(ph),
            .buffer = try std.ArrayList(u8).initCapacity(allocator, 1024),
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

pub fn produce(
    self: *@This(),
    comptime T: type,
    topic: Topic,
    schema_id: u32,
    key: []const u8,
    payload: *T,
) !void {
    self.buffer.shrinkRetainingCapacity(0);

    var writer = self.buffer.writer();
    try writer.writeByte(0);
    try writer.writeInt(u32, schema_id, .big);
    _ = try avro.encode(T, payload, &writer);

    const res = c.rd_kafka_produce(
        topic.t,
        topic.partition,
        c.RD_KAFKA_MSG_F_COPY,
        @constCast(@ptrCast(self.buffer.items)),
        self.buffer.items.len,
        @ptrCast(key),
        key.len,
        null,
    );

    switch (errors.from(res)) {
        ResponseError.NoError => {},
        ResponseError.Unknown => try errors.ok(c.rd_kafka_errno2err(res)),
        else => @panic("Undocumented error code from librdkafka found"),
    }
}

test {
    @import("std").testing.refAllDeclsRecursive(@This());
}
