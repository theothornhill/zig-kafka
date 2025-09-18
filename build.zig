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
    b.installArtifact(librdkafka_artifact);

    const zk = b.addModule("zig-kafka", .{
        .root_source_file = b.path("lib/kafka.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const @"zig-avro" = b.dependency("zig-avro", .{
        .target = target,
        .optimize = optimize,
    });

    zk.addImport("zig-avro", @"zig-avro".module("zig-avro"));

    zk.addIncludePath(librdkafka_artifact.getEmittedIncludeTree());
    zk.linkLibrary(librdkafka_artifact);

    zk.linkSystemLibrary("zlib", .{ .needed = true, .preferred_link_mode = .static });
    zk.linkSystemLibrary("openssl", .{ .needed = true, .preferred_link_mode = .static });
    zk.linkSystemLibrary("libcrypto", .{ .needed = true, .preferred_link_mode = .static });
    zk.linkSystemLibrary("liblz4", .{ .needed = true, .preferred_link_mode = .static });
    zk.linkSystemLibrary("libsasl2", .{ .needed = true, .preferred_link_mode = .static });

    // b.installArtifact(zk);

    const exe_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("lib/kafka.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe_unit_tests.addIncludePath(librdkafka_artifact.getEmittedIncludeTree());
    exe_unit_tests.root_module.addImport("zig-kafka", zk);
    exe_unit_tests.root_module.addImport("zig-avro", @"zig-avro".module("zig-avro"));

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
