const std = @import("std");
const this = @This();

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const librdkafka = b.dependency("librdkafka", .{
        .target = target,
        .optimize = optimize,
    });

    const librdkafka_artifact = librdkafka.artifact("rdkafka");

    const zk = b.addModule("zig-kafka", .{
        .root_source_file = b.path("lib/kafka.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true
    });

    zk.addIncludePath(librdkafka_artifact.getEmittedIncludeTree());
    zk.linkLibrary(librdkafka_artifact);

    zk.linkSystemLibrary("z", .{ .needed = true, .preferred_link_mode = .static });
    zk.linkSystemLibrary("ssl", .{ .needed = true, .preferred_link_mode = .static });
    zk.linkSystemLibrary("crypto", .{ .needed = true, .preferred_link_mode = .static });
    zk.linkSystemLibrary("lz4", .{ .needed = true, .preferred_link_mode = .static });
    zk.linkSystemLibrary("sasl2", .{ .needed = true, .preferred_link_mode = .static });


    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("lib/kafka.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_unit_tests.addIncludePath(librdkafka_artifact.getEmittedIncludeTree());
    exe_unit_tests.root_module.addImport("zig-kafka", zk);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
