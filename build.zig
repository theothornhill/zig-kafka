const std = @import("std");
const this = @This();

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const kafka = b.addSharedLibrary(.{
        .name = "zig-kafka",
        .root_source_file = b.path("lib/kafka.zig"),
        .optimize = optimize,
        .target = target,
    });

    kafka.linkLibC();
    kafka.linkSystemLibrary("rdkafka");

    const zlib_dep = b.dependency("zlib", .{
        .target = target,
        .optimize = optimize,
    });
    kafka.linkLibrary(zlib_dep.artifact("z"));

    const libressl_dependency = b.dependency("libressl", .{
        .target = target,
        .optimize = optimize,
        .@"enable-asm" = true,
    });
    kafka.linkLibrary(libressl_dependency.artifact("ssl"));

    b.installArtifact(kafka);

    const zk = b.addModule("zig-kafka", .{
        .root_source_file = b.path("lib/kafka.zig"),
        .target = target,
        .optimize = optimize,
    });

    zk.linkLibrary(kafka);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("lib/kafka.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
