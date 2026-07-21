const std = @import("std");
const persistence = @import("persistence");

fn databasePath(allocator: std.mem.Allocator, tmp: *const std.testing.TmpDir, suffix: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/{s}.shovel", .{ tmp.sub_path, suffix });
}

fn createProbe(_: *anyopaque, executor: *persistence.Executor) !void {
    _ = try executor.execute("CREATE TABLE wp06_crash (body TEXT);");
    _ = try executor.executeText("INSERT INTO wp06_crash VALUES (", "baseline", ");");
}

fn insertCrashValue(_: *anyopaque, executor: *persistence.Executor) !void {
    _ = try executor.executeText("INSERT INTO wp06_crash VALUES (", "crash-value", ");");
}

fn exitBeforeCommit(_: *anyopaque, executor: *persistence.Executor) !void {
    _ = try executor.executeText("INSERT INTO wp06_crash VALUES (", "uncommitted", ");");
    std.process.exit(77);
}

fn childMode(stage: []const u8, database_path: []const u8) !void {
    var store = if (std.mem.eql(u8, stage, "after-commit"))
        try persistence.testing.openWithFaults(std.testing.allocator, std.testing.io, database_path, .{ .checkpoint = true })
    else if (std.mem.eql(u8, stage, "after-checkpoint"))
        try persistence.testing.openWithFaults(std.testing.allocator, std.testing.io, database_path, .{ .directory_sync = true })
    else
        try persistence.Store.open(std.testing.allocator, std.testing.io, database_path);
    var unused: void = {};
    if (std.mem.eql(u8, stage, "before-commit")) {
        _ = try store.mutate(.{ .context = &unused, .run = exitBeforeCommit });
    } else if (std.mem.eql(u8, stage, "after-commit")) {
        try std.testing.expectError(error.CheckpointFailed, store.mutate(.{ .context = &unused, .run = insertCrashValue }));
    } else if (std.mem.eql(u8, stage, "after-checkpoint")) {
        try std.testing.expectError(error.DirectorySyncFailed, store.mutate(.{ .context = &unused, .run = insertCrashValue }));
    } else if (std.mem.eql(u8, stage, "after-ack")) {
        _ = try store.mutate(.{ .context = &unused, .run = insertCrashValue });
    } else {
        return error.UnknownCrashStage;
    }
    // Deliberately bypass Store.shutdown: the child fixture terminates at the
    // selected durability boundary so ordinary cleanup cannot strengthen it.
    std.process.exit(77);
}

fn runChild(allocator: std.mem.Allocator, stage: []const u8, database_path: []const u8) !void {
    var environment = try std.process.Environ.createMap(std.testing.environ, allocator);
    defer environment.deinit();
    try environment.put("WP06_CRASH_STAGE", stage);
    try environment.put("WP06_CRASH_PATH", database_path);
    const result = try std.process.run(allocator, std.testing.io, .{
        .argv = &.{"/proc/self/exe"},
        .environ_map = &environment,
        .timeout = .{ .duration = .{
            .raw = .fromSeconds(5),
            .clock = .awake,
        } },
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    try std.testing.expectEqual(std.process.Child.Term{ .exited = 77 }, result.term);
}

test "real engine crash-boundary fixture asserts only proven durability guarantees" {
    if (std.process.Environ.getPosix(std.testing.environ, "WP06_CRASH_STAGE")) |stage| {
        const child_path = std.process.Environ.getPosix(std.testing.environ, "WP06_CRASH_PATH") orelse
            return error.MissingCrashPath;
        try childMode(stage, child_path);
        unreachable;
    }

    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const cases = [_]struct { stage: []const u8, exact_count: ?usize }{
        .{ .stage = "before-commit", .exact_count = 1 },
        .{ .stage = "after-commit", .exact_count = null },
        .{ .stage = "after-checkpoint", .exact_count = null },
        .{ .stage = "after-ack", .exact_count = 2 },
    };
    for (cases) |case| {
        const case_path = try databasePath(allocator, &tmp, case.stage);
        defer allocator.free(case_path);
        var store = try persistence.Store.open(allocator, std.testing.io, case_path);
        var unused: void = {};
        _ = try store.mutate(.{ .context = &unused, .run = createProbe });
        try store.shutdown();

        try runChild(allocator, case.stage, case_path);
        store = try persistence.Store.open(allocator, std.testing.io, case_path);
        const observed = try persistence.testing.rowCount(&store, "SELECT body FROM wp06_crash;");
        try store.shutdown();
        if (case.exact_count) |expected| {
            try std.testing.expectEqual(expected, observed);
        } else {
            // A commit without the complete durability boundary is ambiguous;
            // only the previously acknowledged baseline is guaranteed.
            try std.testing.expect(observed >= 1);
        }
    }
}

test "crash fixture public seam remains adapter-opaque" {
    try std.testing.expect(@typeInfo(persistence.Store) == .@"enum");
    try std.testing.expect(@typeInfo(persistence.Executor) == .@"opaque");
    try std.testing.expect(!@hasField(persistence.Store, "_implementation"));
    try std.testing.expect(!@hasDecl(persistence.Store, "rawHandle"));
    try std.testing.expect(!@hasDecl(persistence.Executor, "adapter"));
    try std.testing.expect(@hasDecl(persistence.Store, "startupWrite"));
    try std.testing.expect(@hasDecl(persistence.Store, "mutate"));
    _ = createProbe;
}
