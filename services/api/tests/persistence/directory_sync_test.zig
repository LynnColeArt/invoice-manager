const std = @import("std");
const persistence = @import("persistence");

fn databasePath(allocator: std.mem.Allocator, tmp: *const std.testing.TmpDir, suffix: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/{s}.shovel", .{ tmp.sub_path, suffix });
}

fn createProbe(_: *anyopaque, executor: *persistence.Executor) !void {
    _ = try executor.execute("CREATE TABLE wp06_directory_sync (body TEXT);");
}

test "real Linux directory synchronization follows checkpoint and yields a receipt" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(allocator, &tmp, "real-sync");
    defer allocator.free(path);
    var store = try persistence.Store.open(allocator, std.testing.io, path);
    defer store.shutdown() catch {};
    var unused: void = {};
    const receipt = try store.mutate(.{ .context = &unused, .run = createProbe });
    try std.testing.expectEqual(persistence.State.directory_synchronized, receipt.durability);
    const event_snapshot = persistence.testing.events(&store);
    try std.testing.expectEqualSlices(
        persistence.DurabilityEvent,
        &.{ .transaction_began, .callback_succeeded, .committed, .checkpointed, .directory_synchronized, .receipt_issued },
        event_snapshot.slice(),
    );
}

test "directory open sync and close failures cannot issue receipts" {
    const cases = [_]struct {
        suffix: []const u8,
        faults: persistence.testing.Faults,
        expected: anyerror,
        category: persistence.DiagnosticCategory,
    }{
        .{ .suffix = "open-fail", .faults = .{ .directory_open = true }, .expected = error.DirectoryOpenFailed, .category = .directory_open_failure },
        .{ .suffix = "sync-fail", .faults = .{ .directory_sync = true }, .expected = error.DirectorySyncFailed, .category = .directory_sync_failure },
        .{ .suffix = "close-fail", .faults = .{ .directory_close = true }, .expected = error.DirectoryCloseFailed, .category = .directory_close_failure },
    };
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    for (cases) |case| {
        const path = try databasePath(allocator, &tmp, case.suffix);
        defer allocator.free(path);
        var store = try persistence.testing.openWithFaults(allocator, std.testing.io, path, case.faults);
        defer store.shutdown() catch {};
        var unused: void = {};
        try std.testing.expectError(case.expected, store.mutate(.{ .context = &unused, .run = createProbe }));
        try std.testing.expectEqual(persistence.State.uncertain, store.state());
        try std.testing.expectEqual(case.category, store.lastDiagnostic().?.category);
        try std.testing.expect(!persistence.testing.receiptIssued(&store));
        try std.testing.expectEqual(@as(usize, 0), persistence.testing.openDirectoryCount(&store));
    }
}
