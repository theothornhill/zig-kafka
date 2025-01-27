const std = @import("std");
const this = @This();

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const librdkafka = b.dependency("zig-librdkafka", .{
        .target = target,
        .optimize = optimize,
    });

    const artifact = librdkafka.artifact("rdkafka");

    b.installArtifact(artifact);

    const zlib = b.dependency("zlib", .{
        .target = target,
        .optimize = optimize,
    });

    const z_artifact = zlib.artifact("z");

    // const zlib = b.dependency("zlib", .{
    //     .target = target,
    //     .optimize = optimize,
    // });

    // const z_artifact = zlib.artifact("z");

    b.installArtifact(z_artifact);

    const zk = b.addModule("zig-kafka", .{
        .root_source_file = b.path("lib/kafka.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    zk.addIncludePath(librdkafka.path("include"));
    zk.addObjectFile(librdkafka.path("librdkafka.a"));


    // zk.linkSystemLibrary("rdkafka", .{ .needed = true, .preferred_link_mode = .dynamic });
    zk.linkSystemLibrary("ssl", .{ .needed = true });
    zk.linkSystemLibrary("crypto", .{ .needed = true });
    zk.linkSystemLibrary("sasl2", .{ .needed = true });
    // zk.linkSystemLibrary("curl", .{ .needed = true });
    // zk.addIncludePath(@"zig-librdkafka".path("src"));

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("lib/kafka.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_unit_tests.linkLibC();
    exe_unit_tests.root_module.addImport("zig-kafka", zk);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
