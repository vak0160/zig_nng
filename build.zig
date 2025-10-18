const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const upstream = b.dependency("nng", .{
        .target = target,
        .optimize = optimize,
    });

    const lib_mod = b.createModule(.{
        .optimize = optimize,
        .target = target,
        .link_libc = true,
    });

    const lib = b.addLibrary(.{
        .name = "nng",
        .linkage = .static,
        .root_module = lib_mod,
    });

    // mbedtls
    const upstream_mbedtls = b.dependency("zig_mbedtls", .{
        .target = target,
        .optimize = optimize,
    });
    lib_mod.linkLibrary(upstream_mbedtls.artifact("mbedtls"));

    var arena = std.heap.ArenaAllocator.init(b.allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    var args_arr = std.array_list.Aligned([]const u8, null).empty;

    const NNG_SETSTACKSIZE = b.option(bool, "NNG_SETSTACKSIZE", "Use rlimit for thread stack size.") orelse false;
    if (NNG_SETSTACKSIZE) try args_arr.append(aa, "-DNNG_SETSTACKSIZE");

    const NNG_RESOLV_CONCURRENCY = b.option(usize, "NNG_RESOLV_CONCURRENCY", "Resolver (DNS) concurrency.") orelse 4;
    try args_arr.append(aa, b.fmt("-DNNG_RESOLV_CONCURRENCY={d}", .{NNG_RESOLV_CONCURRENCY}));

    const NNG_NUM_TASKQ_THREADS = b.option(usize, "NNG_NUM_TASKQ_THREADS", "Fixed number of task threads, 0 for automatic.") orelse 0;
    try args_arr.append(aa, b.fmt("-DNNG_NUM_TASKQ_THREADS={d}", .{NNG_NUM_TASKQ_THREADS}));

    const NNG_MAX_TASKQ_THREADS = b.option(usize, "NNG_MAX_TASKQ_THREADS", "Upper bound on task threads, 0 for no limit.") orelse 16;
    try args_arr.append(aa, b.fmt("-DNNG_MAX_TASKQ_THREADS={d}", .{NNG_MAX_TASKQ_THREADS}));

    const NNG_NUM_EXPIRE_THREADS = b.option(usize, "NNG_NUM_EXPIRE_THREADS", "Fixed number of expire threads, 0 for automatic.") orelse 0;
    try args_arr.append(aa, b.fmt("-DNNG_NUM_EXPIRE_THREADS={d}", .{NNG_NUM_EXPIRE_THREADS}));

    const NNG_MAX_EXPIRE_THREADS = b.option(usize, "NNG_MAX_EXPIRE_THREADS", "Upper bound on expire threads, 0 for no limit.") orelse 8;
    try args_arr.append(aa, b.fmt("-DNNG_MAX_EXPIRE_THREADS={d}", .{NNG_MAX_EXPIRE_THREADS}));

    const NNG_NUM_POLLER_THREADS = b.option(usize, "NNG_NUM_POLLER_THREADS", "Fixed number of I/O poller threads, 0 for automatic.") orelse 0;
    try args_arr.append(aa, b.fmt("-DNNG_NUM_POLLER_THREADS={d}", .{NNG_NUM_POLLER_THREADS}));

    const NNG_MAX_POLLER_THREADS = b.option(usize, "NNG_MAX_POLLER_THREADS", "Upper bound on expire threads, 0 for no limit.") orelse 8;
    try args_arr.append(aa, b.fmt("-DNNG_MAX_POLLER_THREADS={d}", .{NNG_MAX_POLLER_THREADS}));

    const NNG_ENABLE_TLS = b.option(bool, "NNG_ENABLE_TLS", "Enable TLS (MBEDTLS).") orelse false;
    if (NNG_ENABLE_TLS) try args_arr.append(aa, "-DNNG_SUPP_TLS");

    switch (target.result.os.tag) {
        .linux => {
            try args_arr.append(aa, "-DNNG_PLATFORM_POSIX");
            try args_arr.append(aa, "-DNNG_PLATFORM_LINUX");
            try args_arr.append(aa, "-DNNG_USE_EVENTFD");

            if (target.result.abi.isAndroid()) {
                try args_arr.append(aa, "-DNNG_PLATFORM_ANDROID");
            } else {
                try args_arr.append(aa, "-DNNG_HAVE_ABSTRACT_SOCKETS");
            }
        },
        .macos => {
            try args_arr.append(aa, "-DNNG_PLATFORM_POSIX");
            try args_arr.append(aa, "-DNNG_PLATFORM_DARWIN");
        },
        .freebsd => {
            try args_arr.append(aa, "-DNNG_PLATFORM_POSIX");
            try args_arr.append(aa, "-DNNG_PLATFORM_FREEBSD");
        },
        .netbsd => {
            try args_arr.append(aa, "-DNNG_PLATFORM_POSIX");
            try args_arr.append(aa, "-DNNG_PLATFORM_NETBSD");
        },
        .openbsd => {
            try args_arr.append(aa, "-DNNG_PLATFORM_POSIX");
            try args_arr.append(aa, "-DNNG_PLATFORM_OPENBSD");
        },
        .solaris => {
            try args_arr.append(aa, "-DNNG_PLATFORM_POSIX");
            try args_arr.append(aa, "-DNNG_PLATFORM_SUNOS");
        },
        .windows => {
            try args_arr.append(aa, "-DNNG_PLATFORM_WINDOWS");
            try args_arr.append(aa, "-D_CRT_SECURE_NO_WARNINGS");
            try args_arr.append(aa, "-D_CRT_RAND_S");
            try args_arr.append(aa, "-D_WIN32_WINNT=0x0600");
        },
        else => {
            @panic(b.fmt("OS ({s}) not supported!", .{@tagName(target.result.os.tag)}));
        },
    }

    lib_mod.addCSourceFiles(.{
        .root = upstream.path("src"),
        .files = &.{
            "compat/nanomsg/nn.c",
            "core/aio.c",
            "core/device.c",
            "core/dialer.c",
            "core/file.c",
            "core/idhash.c",
            "core/init.c",
            "core/list.c",
            "core/listener.c",
            "core/lmq.c",
            "core/log.c",
            "core/message.c",
            "core/msgqueue.c",
            "core/options.c",
            "core/panic.c",
            "core/pipe.c",
            "core/pollable.c",
            "core/reap.c",
            "core/sockaddr.c",
            "core/socket.c",
            "core/sockfd.c",
            "core/stats.c",
            "core/stream.c",
            "core/strs.c",
            "core/taskq.c",
            "core/tcp.c",
            "core/thread.c",
            "core/url.c",
            "nng.c",
            "nng_legacy.c",
            "sp/protocol/bus0/bus.c",
            "sp/protocol/pair0/pair.c",
            "sp/protocol/pair1/pair.c",
            "sp/protocol/pair1/pair1_poly.c",
            "sp/protocol/pipeline0/pull.c",
            "sp/protocol/pipeline0/push.c",
            "sp/protocol/pubsub0/pub.c",
            "sp/protocol/pubsub0/sub.c",
            "sp/protocol/pubsub0/xsub.c",
            "sp/protocol/reqrep0/rep.c",
            "sp/protocol/reqrep0/req.c",
            "sp/protocol/reqrep0/xrep.c",
            "sp/protocol/reqrep0/xreq.c",
            "sp/protocol/survey0/respond.c",
            "sp/protocol/survey0/survey.c",
            "sp/protocol/survey0/xrespond.c",
            "sp/protocol/survey0/xsurvey.c",
            "sp/protocol.c",
            "sp/transport/inproc/inproc.c",
            "sp/transport/ipc/ipc.c",
            "sp/transport/socket/sockfd.c",
            "sp/transport/tcp/tcp.c",
            "sp/transport/tls/tls.c",
            "sp/transport/ws/websocket.c",
            // "sp/transport/zerotier/zerotier.c",
            // "sp/transport/zerotier/zthash.c",
            "sp/transport.c",
            "supplemental/base64/base64.c",
            "supplemental/http/http_chunk.c",
            "supplemental/http/http_client.c",
            "supplemental/http/http_conn.c",
            "supplemental/http/http_msg.c",
            "supplemental/http/http_public.c",
            "supplemental/http/http_schemes.c",
            "supplemental/http/http_server.c",
            "supplemental/sha1/sha1.c",
            "supplemental/tls/mbedtls/tls.c",
            "supplemental/tls/tls_common.c",
            // "supplemental/tls/wolfssl/wolfssl.c",
            "supplemental/util/idhash.c",
            "supplemental/util/options.c",
            // "supplemental/websocket/stub.c",
            "supplemental/websocket/websocket.c",
            // "tools/nngcat/nngcat.c",
            // "tools/perf/perf.c",
            // "tools/perf/pubdrop.c",
        },
        .flags = args_arr.items,
    });

    switch (target.result.os.tag) {
        .windows => {
            lib_mod.addCSourceFiles(.{
                .root = upstream.path("src"),
                .files = &.{
                    "platform/windows/win_clock.c",
                    "platform/windows/win_debug.c",
                    "platform/windows/win_file.c",
                    "platform/windows/win_io.c",
                    "platform/windows/win_ipcconn.c",
                    "platform/windows/win_ipcdial.c",
                    "platform/windows/win_ipclisten.c",
                    "platform/windows/win_pipe.c",
                    "platform/windows/win_rand.c",
                    "platform/windows/win_resolv.c",
                    "platform/windows/win_sockaddr.c",
                    "platform/windows/win_socketpair.c",
                    "platform/windows/win_tcp.c",
                    "platform/windows/win_tcpconn.c",
                    "platform/windows/win_tcpdial.c",
                    "platform/windows/win_tcplisten.c",
                    "platform/windows/win_thread.c",
                    "platform/windows/win_udp.c",
                },
                .flags = args_arr.items,
            });
        },
        else => {
            lib_mod.addCSourceFiles(.{
                .root = upstream.path("src"),
                .files = &.{
                    "platform/posix/posix_alloc.c",
                    "platform/posix/posix_atomic.c",
                    "platform/posix/posix_clock.c",
                    "platform/posix/posix_debug.c",
                    "platform/posix/posix_file.c",
                    "platform/posix/posix_ipcconn.c",
                    "platform/posix/posix_ipcdial.c",
                    "platform/posix/posix_ipclisten.c",
                    "platform/posix/posix_peerid.c",
                    "platform/posix/posix_pipe.c",
                    "platform/posix/posix_pollq_epoll.c",
                    "platform/posix/posix_pollq_kqueue.c",
                    "platform/posix/posix_pollq_poll.c",
                    "platform/posix/posix_pollq_port.c",
                    "platform/posix/posix_rand_arc4random.c",
                    "platform/posix/posix_rand_getrandom.c",
                    "platform/posix/posix_rand_urandom.c",
                    "platform/posix/posix_resolv_gai.c",
                    "platform/posix/posix_sockaddr.c",
                    "platform/posix/posix_socketpair.c",
                    "platform/posix/posix_sockfd.c",
                    "platform/posix/posix_tcpconn.c",
                    "platform/posix/posix_tcpdial.c",
                    "platform/posix/posix_tcplisten.c",
                    "platform/posix/posix_thread.c",
                    "platform/posix/posix_udp.c",
                },
                .flags = args_arr.items,
            });
        },
    }

    lib_mod.addIncludePath(upstream.path("src"));
    lib_mod.addIncludePath(upstream.path("include"));

    lib.installHeadersDirectory(upstream.path("include"), "", .{});

    b.installArtifact(lib);
}
