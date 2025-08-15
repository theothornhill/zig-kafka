const std = @import("std");
const c = @import("c.zig").c;
const config = @import("config.zig");
const errors = @import("errors.zig");
const ResponseError = errors.ResponseError;

t: ?*c.rd_kafka_topic_t,

name: []const u8,
partition: i32 = c.RD_KAFKA_PARTITION_UA,

const Topic = @This();

pub fn init(handle: *c.rd_kafka_t, name: []const u8) Topic {
    return .{
        .t = c.rd_kafka_topic_new(
            handle,
            @constCast(@ptrCast(name)),
            null,
        ),
        .name = name,
    };
}

pub fn deinit(self: Topic) void {
    std.log.info("Destroying topic", .{});
    c.rd_kafka_topic_destroy(self.t);
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

fn empty(self: Topic) bool {
    return self.msg == null;
}

fn length(self: Topic) usize {
    return self.msg.?.len;
}
