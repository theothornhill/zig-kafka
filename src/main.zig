const std = @import("std");
const log = std.log;

const k = @import("kafka");
const ResponseError = k.ResponseError;
const avro = @import("zig-avro");

const Record = struct {
    valid: ?bool,
    message: []const u8,
    items: avro.Array(i32),
    onion: union(enum) {
        str: []const u8,
        number: i32,
        none,
    },
};

pub fn main() !void {
    var val: [10]u8 = [_]u8{
        1 << 1,
        1, // valid: true
        2 << 1, // message:len 2
        'H',
        'I',
        1 << 1, // items array: len 1
        5 << 1, // items[0] = 5
        0, // end of array
        1 << 1,
        2 << 1, // message:len 2
    };
    var keyPayload: [3]u8 = [_]u8{ 'f', 'o', 'o' };

    var producer = try k.Producer.Producer.init();
    var consumer = try k.Consumer.Consumer.init();
    _ = try consumer.subscribe();

    const top = k.Topic.init(producer.handle, "rs-load-fast-event-v1");
    defer top.deinit();

    var timer = try std.time.Timer.start();
    var start: u64 = 0;
    const mesg = k.Producer.Message.init(
        top,
        &val,
        &keyPayload,
    );
    std.debug.print("mesg {}", .{mesg});

    var i: usize = 0;
    while (i < 1000000) : (i += 1) {
        // log.info("producing: key: {s}, val: {x}", .{ keyPayload, val });
        _ = try producer.produce(
            mesg,
        );

        if (i % 100000 == 0) {
            try producer.poll(10);
        }

        const msg = consumer.poll(5) catch |err| switch (err) {
            ResponseError.PartitionEOF => continue,
            ResponseError.NoOffset => continue,
            else => return err,
        };

        if (msg) |message| {
            if (start == 0) {
                std.debug.print("\nstarting\n", .{});
                start = timer.lap();
            }
            defer message.deinit();
            if (message.payload) |payload| {
                var r: Record = undefined;
                _ = try avro.read(Record, &r, payload);

                if (i % 100000 == 0) {
                    std.debug.print("record: {s}, {}, {} - ", .{ r.message, r.valid.?, r.onion.number });
                    std.debug.print("key: {s} - ", .{message.key});
                    std.debug.print("offset: {any}\n", .{message.offset});
                }
            }
            try consumer.commit();
        }
    }
    try producer.poll(10);
    const end = timer.lap();
    std.debug.print("time:: {}", .{(end - start) / 1_000_000});
}
