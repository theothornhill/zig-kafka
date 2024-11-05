const std = @import("std");
const this = @This();

pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const kafka = b.addSharedLibrary(.{
        .name = "zig-kafka",
        .root_source_file = b.path("lib/kafka.zig"),
        .optimize = optimize,
        .target = target,
    });

    kafka.linkLibC();
    // kafka.linkSystemLibrary("sasl2");
    // kafka.linkSystemLibrary("curl");
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

    // const cflags = &[_][]const u8{
    //     "-g",
    //     "-O3",
    //     "-fPIC",
    //     // Too much ub in librdkafka to be funny
    //     "-fno-sanitize=all",
    //     "-Wall",
    //     "-Wsign-compare",
    //     "-Wfloat-equal",
    //     "-Wpointer-arith",
    //     "-Wcast-align",
    // };
    // kafka.addIncludePath(b.path("c/librdkafka/"));
    // kafka.addIncludePath(b.path("c/librdkafka/src"));
    // kafka.addIncludePath(b.path("c/librdkafka/src/nanopb"));
    // kafka.addIncludePath(b.path("c/librdkafka/src/opentelemetry"));
    // kafka.addCSourceFiles(.{
    //     .files = &.{
    //         "c/librdkafka/src/nanopb/pb_common.c",
    //         "c/librdkafka/src/nanopb/pb_decode.c",
    //         "c/librdkafka/src/nanopb/pb_encode.c",
    //         "c/librdkafka/src/opentelemetry/common.pb.c",
    //         "c/librdkafka/src/opentelemetry/metrics.pb.c",
    //         "c/librdkafka/src/opentelemetry/resource.pb.c",
    //         "c/librdkafka/src/lz4frame.c",
    //         "c/librdkafka/src/lz4.c",
    //         "c/librdkafka/src/lz4hc.c",
    //         "c/librdkafka/src/snappy.c",
    //         "c/librdkafka/src/cJSON.c",
    //         "c/librdkafka/src/rdmurmur2.c",
    //         "c/librdkafka/src/crc32c.c",
    //         "c/librdkafka/src/rdstring.c",
    //         "c/librdkafka/src/rdregex.c",
    //         "c/librdkafka/src/rdrand.c",
    //         "c/librdkafka/src/rdxxhash.c",
    //         "c/librdkafka/src/rdavl.c",
    //         "c/librdkafka/src/rdvarint.c",
    //         "c/librdkafka/src/rddl.c",
    //         "c/librdkafka/src/rdbase64.c",
    //         "c/librdkafka/src/rdaddr.c",
    //         "c/librdkafka/src/rdfnv1a.c",
    //         "c/librdkafka/src/rdhttp.c",
    //         "c/librdkafka/src/rdunittest.c",
    //         "c/librdkafka/src/rdgz.c",
    //         "c/librdkafka/src/rdcrc32.c",
    //         "c/librdkafka/src/rdbuf.c",
    //         "c/librdkafka/src/rdlog.c",
    //         "c/librdkafka/src/rdports.c",
    //         "c/librdkafka/src/rdmap.c",
    //         "c/librdkafka/src/rdlist.c",
    //         "c/librdkafka/src/rdhdrhistogram.c",
    //         "c/librdkafka/src/rdkafka.c",
    //         "c/librdkafka/src/rdkafka_admin.c",
    //         "c/librdkafka/src/rdkafka_assignment.c",
    //         "c/librdkafka/src/rdkafka_assignor.c",
    //         "c/librdkafka/src/rdkafka_aux.c",
    //         "c/librdkafka/src/rdkafka_background.c",
    //         "c/librdkafka/src/rdkafka_broker.c",
    //         "c/librdkafka/src/rdkafka_buf.c",
    //         "c/librdkafka/src/rdkafka_cert.c",
    //         "c/librdkafka/src/rdkafka_cgrp.c",
    //         "c/librdkafka/src/rdkafka_conf.c",
    //         "c/librdkafka/src/rdkafka_coord.c",
    //         "c/librdkafka/src/rdkafka_error.c",
    //         "c/librdkafka/src/rdkafka_event.c",
    //         "c/librdkafka/src/rdkafka_feature.c",
    //         "c/librdkafka/src/rdkafka_fetcher.c",
    //         "c/librdkafka/src/rdkafka_header.c",
    //         "c/librdkafka/src/rdkafka_idempotence.c",
    //         "c/librdkafka/src/rdkafka_interceptor.c",
    //         "c/librdkafka/src/rdkafka_lz4.c",
    //         "c/librdkafka/src/rdkafka_metadata.c",
    //         "c/librdkafka/src/rdkafka_metadata_cache.c",
    //         "c/librdkafka/src/rdkafka_mock.c",
    //         "c/librdkafka/src/rdkafka_mock_cgrp.c",
    //         "c/librdkafka/src/rdkafka_mock_handlers.c",
    //         "c/librdkafka/src/rdkafka_msg.c",
    //         "c/librdkafka/src/rdkafka_msgset_reader.c",
    //         "c/librdkafka/src/rdkafka_msgset_writer.c",
    //         "c/librdkafka/src/rdkafka_offset.c",
    //         "c/librdkafka/src/rdkafka_op.c",
    //         "c/librdkafka/src/rdkafka_partition.c",
    //         "c/librdkafka/src/rdkafka_pattern.c",
    //         "c/librdkafka/src/rdkafka_plugin.c",
    //         "c/librdkafka/src/rdkafka_queue.c",
    //         "c/librdkafka/src/rdkafka_range_assignor.c",
    //         "c/librdkafka/src/rdkafka_request.c",
    //         "c/librdkafka/src/rdkafka_roundrobin_assignor.c",
    //         "c/librdkafka/src/rdkafka_sasl.c",
    //         "c/librdkafka/src/rdkafka_sasl_cyrus.c",
    //         "c/librdkafka/src/rdkafka_sasl_oauthbearer.c",
    //         "c/librdkafka/src/rdkafka_sasl_oauthbearer_oidc.c",
    //         "c/librdkafka/src/rdkafka_sasl_plain.c",
    //         "c/librdkafka/src/rdkafka_sasl_scram.c",
    //         //"c/librdkafka/src/rdkafka_sasl_win32.c",
    //         "c/librdkafka/src/rdkafka_ssl.c",
    //         "c/librdkafka/src/rdkafka_sticky_assignor.c",
    //         "c/librdkafka/src/rdkafka_subscription.c",
    //         "c/librdkafka/src/rdkafka_telemetry.c",
    //         "c/librdkafka/src/rdkafka_telemetry_decode.c",
    //         "c/librdkafka/src/rdkafka_telemetry_encode.c",
    //         "c/librdkafka/src/rdkafka_timer.c",
    //         "c/librdkafka/src/rdkafka_topic.c",
    //         "c/librdkafka/src/rdkafka_transport.c",
    //         "c/librdkafka/src/rdkafka_txnmgr.c",
    //         // "c/librdkafka/src/rdkafka_zstd.c",
    //         "c/librdkafka/src/tinycthread.c",
    //         "c/librdkafka/src/tinycthread_extra.c",
    //     },
    //     .flags = cflags,
    // });

    b.installArtifact(kafka);


    const zk = b.addModule("zig-kafka", .{
        .root_source_file = b.path("lib/kafka.zig"),
        .target = target,
        .optimize = optimize,
    });

    zk.linkLibrary(kafka);
    zk.addIncludePath(b.path("c/librdkafka/"));
    zk.addIncludePath(b.path("c/librdkafka/src"));
    zk.addIncludePath(b.path("c/librdkafka/src/nanopb"));
    zk.addIncludePath(b.path("c/librdkafka/src/opentelemetry"));
    // zk.addImport("zig-kafka", &kafka.root_module);


    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("lib/kafka.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_unit_tests.addIncludePath(b.path("c/librdkafka/"));
    exe_unit_tests.addIncludePath(b.path("c/librdkafka/src"));
    exe_unit_tests.addIncludePath(b.path("c/librdkafka/src/nanopb"));
    exe_unit_tests.addIncludePath(b.path("c/librdkafka/src/opentelemetry"));
    // exe_unit_tests.root_module.addImport("kafka", &kafka.root_module);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
