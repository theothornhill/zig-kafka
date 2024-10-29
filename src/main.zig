const std = @import("std");
const log = std.log;

const k = @import("kafka");
const ResponseError = k.ResponseError;
const avro = @import("zig-avro");

const Record = struct {
    happy: bool,
    arms: i32,
    legs: i64,
    width: f32,
    height: f64,
};

const num_messages = 1_000_000;

fn produce() !void {
    var keyPayload: [3]u8 = [_]u8{ 'f', 'o', 'o' };

    var cfg = try k.Config.init();
    try cfg.set("bootstrap.servers", "kafka:9092");
    try cfg.set("request.required.acks", "all");
    // try cfg.set("debug", "broker,topic,msg");
    // try cfg.set("linger.ms", "0");

    var writeBuffer: [100]u8 = undefined;
    var r1: Record = .{
        .happy = true,
        .arms = 1_000_000,
        .legs = 0,
        .width = 5.5,
        .height = 93203291039213.9012,
    };

    var producer = try k.Producer.init(cfg);
    defer producer.deinit();

    const top = k.Topic.init(producer.handle, "rs-load-fast-event-v1");
    defer top.deinit();

    var timer = try std.time.Timer.start();
    var start: u64 = 0;
    start = timer.lap();
    var i: usize = 0;

    while (i < num_messages) : (i += 1) {
        _ = try producer.produce(k.Producer.Message.init(
            top,
            try avro.Writer.write(Record, &r1, &writeBuffer),
            &keyPayload,
        ));

        if (i % 100000 == 0) {
            try producer.poll(10);
        }
    }
    try producer.poll(10);
    const end = timer.lap();

    std.debug.print("\nDone producing messages - time:: {}\n", .{(end - start) / 1_000_000});
}

fn consume() !void {
    var cfg = try k.Config.init();
    try cfg.set("bootstrap.servers", "kafka:9092");
    try cfg.set("auto.offset.reset", "earliest");
    try cfg.set("auto.commit.interval.ms", "10000");
    try cfg.set("fetch.wait.max.ms", "50000");
    try cfg.set("queued.min.messages", "1000000");
    try cfg.set("group.id", "theoestnenisretn");
    // try cfg.set("fetch.queue.backoff.ms", "100");
    // try cfg.set("enable.auto.commit", "false");
    // try cfg.set("debug", "consumer");

    var consumer = try k.Consumer.Consumer.init(cfg);
    defer consumer.deinit();
    _ = try consumer.subscribe();

    var timer = try std.time.Timer.start();
    var start: u64 = 0;
    var i: usize = 0;
    var r: Record = undefined;
    start = timer.lap();
    while (i < num_messages) : (i += 1) {
        const msg = consumer.poll(5) catch |err| switch (err) {
            ResponseError.PartitionEOF => continue,
            ResponseError.NoOffset => return,
            else => return err,
        };

        if (msg) |message| {
            defer message.deinit();
            if (message.payload) |payload| {
                _ = try avro.Reader.read(Record, &r, payload);

                if (i % 100000 == 0) {
                    std.debug.print("Reading...\n", .{});
                }
            }
        }
    }
    const end = timer.lap();
    std.debug.print("\nDone consuming messages - time:: {}\n", .{(end - start) / 1_000_000});
    std.debug.print("record: {}, {}, {}, {}, {}\n", .{ r.happy, r.arms, r.height, r.legs, r.width });
}

pub fn main() !void {
    const producer = try std.Thread.spawn(.{}, produce, .{});
    const consumer = try std.Thread.spawn(.{}, consume, .{});

    producer.join();
    consumer.join();
}
