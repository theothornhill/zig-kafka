const std = @import("std");
const log = std.log;
const c = @import("c.zig").c;
const cfg = @import("config.zig");

pub const Config = cfg.Config;
pub const LogLevel = cfg.LogLevel;


test {
    @import("std").testing.refAllDecls(@This());
}
