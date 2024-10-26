const std = @import("std");
const log = std.log;

const k = @import("kafka");
const ResponseError = k.ResponseError;
const avro = @import("zigavro");

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

    log.info("producing: key: {s}, val: {x}", .{ keyPayload, val });

    _ = try producer.produce(
        k.Producer.Message.init(
            k.Topic.init(producer.handle, "rs-load-fast-event-v1"),
            &val,
            &keyPayload,
        ),
    );

    var consumer = try k.Consumer.Consumer.init();

    _ = try consumer.subscribe();

    while (true) {
        const msg = consumer.poll(250) catch |err| switch (err) {
            ResponseError.PartitionEOF => continue,
            ResponseError.Ignorable => continue,
            else => return err,
        };

        if (msg) |message| {
            // defer message.deinit();
            if (message.payload) |payload| {
                var r: Record = undefined;
                _ = try avro.read(Record, &r, payload);

                std.debug.print("record: {s}, {}, {}\n", .{ r.message, r.valid.?, r.onion.number });
                std.debug.print("key: {s}\n", .{message.key});
                std.debug.print("offset: {any}\n", .{message.offset});
            }
        }
    }
}
