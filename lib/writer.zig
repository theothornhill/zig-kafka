const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const Producer = @import("producer.zig").Producer;
const Topic = @import("topic.zig");
const errors = @import("errors.zig");
const ResponseError = errors.ResponseError;

const Context = struct {
    producer: *Producer,
    topic: Topic,
    key: []const u8,
};

const Self = @This();
pub const Error = anyerror;

pub const Writer = std.io.GenericWriter(Context, Error, write);

pub fn write(self: Self, bytes: []const u8) Error!usize {
    // TODO: This needs to not be tied to the key on init. But my brain is too
    // small.
    const msg = Producer.Message.init(
        self.topic,
        bytes,
        self.key,
    );
    self.producer.produce(msg);
    // TODO: return something more meaningful here
    return self.value.len;
}
