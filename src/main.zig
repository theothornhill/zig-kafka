const std = @import("std");
const log = std.log;

const k = @import("kafka");

pub fn main() !void {
    const conf = try k.Config.init();

    try conf.setLogLevel(.Crit);

    // Dump should show log.level => 2
    conf.dump();
}

test "create config" {
    const config: k.Config = try k.Config.init();
    std.debug.print("LONNGGNNG: {}", .{config});
}