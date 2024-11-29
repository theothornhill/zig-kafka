const std = @import("std");
const this = @This();

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const upstream = b.dependency("upstream", .{
        .target = target,
        .optimize = optimize,
    });

    const zk = b.addModule("zig-kafka", .{
        .root_source_file = b.path("lib/kafka.zig"),
        .target = target,
        .optimize = optimize,
    });

    zk.linkSystemLibrary("rdkafka", .{});
    zk.addIncludePath(upstream.path("src"));

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("lib/kafka.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_unit_tests.addIncludePath(upstream.path("src"));
    exe_unit_tests.root_module.addImport("zig-kafka", zk);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);


    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
