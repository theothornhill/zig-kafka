const std = @import("std");
const this = @This();

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const upstream = b.dependency("upstream", .{
        .target = target,
        .optimize = optimize,
    });

    const zlib_dep = b.dependency("zlib", .{
        .target = target,
        .optimize = optimize,
    });

    const zstd_dep = b.dependency("zstd", .{
        .target = target,
        .optimize = optimize,
    });

    const rdkafka = b.addStaticLibrary(.{
        .name = "rdkafka",
        .optimize = optimize,
        .target = target,
    });

    const configure = b.option(bool, "configure", "Whether to run ./configure or not") orelse true;

    if (configure) {
        const configure_cmd = upstream.builder.addSystemCommand(&[_][]const u8{
            "./configure",
            "--install-deps",
            "--source-deps-only",
            "--enable-static",
        });
        configure_cmd.step.dependOn(upstream.builder.default_step);
        rdkafka.step.dependOn(&configure_cmd.step);
    }

    rdkafka.addCSourceFiles(.{
        .root = upstream.path("."),
        .files = sources,
        .flags = cflags,
    });

    rdkafka.addCSourceFiles(.{
        .root = upstream.path("src"),
        .files = other_sources,
        .flags = cflags,
    });

    rdkafka.addIncludePath(upstream.path("src"));

    rdkafka.linkLibC();
    rdkafka.linkLibrary(zlib_dep.artifact("z"));
    rdkafka.linkLibrary(zstd_dep.artifact("zstd"));
    rdkafka.addObjectFile(upstream.path("mklove/deps/dest/usr/lib/libcurl.a"));
    rdkafka.addObjectFile(upstream.path("mklove/deps/dest/usr/lib64/libssl.a"));
    rdkafka.addObjectFile(upstream.path("mklove/deps/dest/usr/lib64/libcrypto.a"));

    b.installArtifact(rdkafka);

    const zk = b.addModule("zig-kafka", .{
        .root_source_file = b.path("lib/kafka.zig"),
        .target = target,
        .optimize = optimize,
    });

    zk.linkLibrary(rdkafka);
    zk.addIncludePath(upstream.path("src"));
    zk.addObjectFile(upstream.path("mklove/deps/dest/usr/lib/libcurl.a"));
    zk.addObjectFile(upstream.path("mklove/deps/dest/usr/lib64/libssl.a"));
    zk.addObjectFile(upstream.path("mklove/deps/dest/usr/lib64/libcrypto.a"));

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("lib/kafka.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_unit_tests.linkLibrary(rdkafka);
    zk.addIncludePath(upstream.path("src"));

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}

const cflags = &[_][]const u8{
    "-g",
    "-O3",
    "-fno-sanitize=undefined",
    "-fPIC",
    "-Wall",
    "-Wsign-compare",
    "-Wfloat-equal",
    "-Wpointer-arith",
    "-Wcast-align",
};

const sources: []const []const u8 = &.{
    "src/lz4frame.c",
    "src/lz4.c",
    "src/lz4hc.c",
    "src/snappy.c",
    "src/cJSON.c",
    "src/rdmurmur2.c",
    "src/crc32c.c",
    "src/rdstring.c",
    "src/rdregex.c",
    "src/rdrand.c",
    "src/rdxxhash.c",
    "src/rdavl.c",
    "src/rdvarint.c",
    "src/rddl.c",
    "src/rdbase64.c",
    "src/rdaddr.c",
    "src/rdfnv1a.c",
    "src/rdhttp.c",
    "src/rdunittest.c",
    "src/rdgz.c",
    "src/rdcrc32.c",
    "src/rdbuf.c",
    "src/rdlog.c",
    "src/rdports.c",
    "src/rdmap.c",
    "src/rdlist.c",
    "src/rdhdrhistogram.c",
    "src/rdkafka.c",
    "src/rdkafka_admin.c",
    "src/rdkafka_assignment.c",
    "src/rdkafka_assignor.c",
    "src/rdkafka_aux.c",
    "src/rdkafka_background.c",
    "src/rdkafka_broker.c",
    "src/rdkafka_buf.c",
    "src/rdkafka_cert.c",
    "src/rdkafka_cgrp.c",
    "src/rdkafka_conf.c",
    "src/rdkafka_coord.c",
    "src/rdkafka_error.c",
    "src/rdkafka_event.c",
    "src/rdkafka_feature.c",
    "src/rdkafka_fetcher.c",
    "src/rdkafka_header.c",
    "src/rdkafka_idempotence.c",
    "src/rdkafka_interceptor.c",
    "src/rdkafka_lz4.c",
    "src/rdkafka_metadata.c",
    "src/rdkafka_metadata_cache.c",
    "src/rdkafka_msg.c",
    "src/rdkafka_msgset_reader.c",
    "src/rdkafka_msgset_writer.c",
    "src/rdkafka_offset.c",
    "src/rdkafka_op.c",
    "src/rdkafka_partition.c",
    "src/rdkafka_pattern.c",
    "src/rdkafka_plugin.c",
    "src/rdkafka_queue.c",
    "src/rdkafka_range_assignor.c",
    "src/rdkafka_request.c",
    "src/rdkafka_roundrobin_assignor.c",
    "src/rdkafka_sasl.c",
    "src/rdkafka_sasl_cyrus.c",
    "src/rdkafka_sasl_oauthbearer.c",
    "src/rdkafka_sasl_oauthbearer_oidc.c",
    "src/rdkafka_sasl_plain.c",
    "src/rdkafka_sasl_scram.c",
    "src/rdkafka_ssl.c",
    "src/rdkafka_sticky_assignor.c",
    "src/rdkafka_subscription.c",
    "src/rdkafka_timer.c",
    "src/rdkafka_topic.c",
    "src/rdkafka_transport.c",
    "src/rdkafka_txnmgr.c",
    "src/rdkafka_zstd.c",
    "src/tinycthread.c",
    "src/tinycthread_extra.c",
    "src/rdkafka_telemetry.c",
    "src/rdkafka_telemetry_decode.c",
    "src/rdkafka_telemetry_encode.c",
    // "rdkafka_sasl_win32.c",
    "src/rdkafka_mock.c",
    "src/rdkafka_mock_cgrp.c",
    "src/rdkafka_mock_handlers.c",
};

const other_sources: []const []const u8 = &.{
    "nanopb/pb_common.c",
    "nanopb/pb_decode.c",
    "nanopb/pb_encode.c",
    "opentelemetry/common.pb.c",
    "opentelemetry/metrics.pb.c",
    "opentelemetry/resource.pb.c",
};
