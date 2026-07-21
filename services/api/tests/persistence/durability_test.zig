const std = @import("std");
const persistence = @import("persistence");

fn databasePath(allocator: std.mem.Allocator, tmp: *const std.testing.TmpDir, suffix: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/{s}.shovel", .{ tmp.sub_path, suffix });
}

const CallbackContext = struct {
    calls: usize = 0,
    fail: bool = false,
};

fn callback(raw_context: *anyopaque, executor: *persistence.Executor) !void {
    const context: *CallbackContext = @ptrCast(@alignCast(raw_context));
    context.calls += 1;
    _ = try executor.execute("CREATE TABLE wp06_durability (body TEXT);");
    if (context.fail) return error.ExpectedCallbackFailure;
}

fn insertAndFail(raw_context: *anyopaque, executor: *persistence.Executor) !void {
    const context: *CallbackContext = @ptrCast(@alignCast(raw_context));
    context.calls += 1;
    _ = try executor.executeText("INSERT INTO wp06_durability VALUES (", "rolled-back", ");");
    return error.ExpectedCallbackFailure;
}

test "callback failure rolls back exactly once and creates no receipt" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(allocator, &tmp, "callback");
    defer allocator.free(path);
    var store = try persistence.Store.open(allocator, std.testing.io, path);
    defer store.shutdown() catch {};

    var context = CallbackContext{};
    _ = try store.mutate(.{ .context = &context, .run = callback });
    context.calls = 0;
    try std.testing.expectError(error.CallbackFailed, store.mutate(.{ .context = &context, .run = insertAndFail }));
    try std.testing.expectEqual(@as(usize, 1), context.calls);
    try std.testing.expectEqual(persistence.State.ready, store.state());
    try std.testing.expectEqual(persistence.DiagnosticCategory.callback_failure, store.lastDiagnostic().?.category);
    try std.testing.expectEqual(
        @as(usize, 0),
        try persistence.testing.rowCount(&store, "SELECT body FROM wp06_durability;"),
    );
}

test "receipt requires commit checkpoint and parent-directory synchronization" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(allocator, &tmp, "receipt");
    defer allocator.free(path);
    var store = try persistence.Store.open(allocator, std.testing.io, path);
    defer store.shutdown() catch {};

    var context = CallbackContext{};
    const receipt = try store.mutate(.{ .context = &context, .run = callback });
    try std.testing.expectEqual(@as(usize, 1), context.calls);
    try std.testing.expectEqual(persistence.State.directory_synchronized, receipt.durability);
    try std.testing.expect(receipt.operation_id > 0);
    try std.testing.expectEqual(persistence.State.ready, store.state());
}

test "post-commit checkpoint failure is uncertain and quarantines future writes" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(allocator, &tmp, "uncertain");
    defer allocator.free(path);
    var store = try persistence.testing.openWithFaults(
        allocator,
        std.testing.io,
        path,
        .{ .checkpoint = true },
    );
    defer store.shutdown() catch {};

    var context = CallbackContext{};
    try std.testing.expectError(error.CheckpointFailed, store.mutate(.{ .context = &context, .run = callback }));
    try std.testing.expectEqual(persistence.State.uncertain, store.state());
    persistence.testing.setFaults(&store, .{});
    try std.testing.expectError(error.StoreQuarantined, store.mutate(.{ .context = &context, .run = callback }));
    try std.testing.expectEqual(persistence.State.quarantined, store.state());
}

test "failed startup write discards without checkpoint and reopens last durable snapshot" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(allocator, &tmp, "startup-recover");
    defer allocator.free(path);
    var store = try persistence.Store.open(allocator, std.testing.io, path);
    defer store.shutdown() catch {};

    var context = CallbackContext{ .fail = true };
    try std.testing.expectError(error.StartupWriteFailed, store.startupWrite(.{ .context = &context, .run = callback }));
    try std.testing.expectEqual(@as(usize, 1), context.calls);
    try std.testing.expectEqual(persistence.State.ready, store.state());
    try std.testing.expectEqual(@as(usize, 0), persistence.testing.checkpointCount(&store));
    try std.testing.expectEqual(@as(usize, 1), persistence.testing.discardCount(&store));
    try std.testing.expectEqual(@as(usize, 1), persistence.testing.reopenCount(&store));
    try std.testing.expectError(
        error.QueryFailed,
        persistence.testing.rowCount(&store, "SELECT body FROM wp06_durability;"),
    );
}

test "failed startup reopen quarantines and preserves a typed diagnostic" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(allocator, &tmp, "startup-quarantine");
    defer allocator.free(path);
    var store = try persistence.testing.openWithFaults(
        allocator,
        std.testing.io,
        path,
        .{ .reopen = true },
    );
    defer store.shutdown() catch {};

    var context = CallbackContext{ .fail = true };
    try std.testing.expectError(error.ReopenFailed, store.startupWrite(.{ .context = &context, .run = callback }));
    try std.testing.expectEqual(persistence.State.quarantined, store.state());
    const diagnostic = store.lastDiagnostic().?;
    try std.testing.expectEqual(persistence.DiagnosticCategory.reopen_failure, diagnostic.category);
    try std.testing.expectEqual(@as(?[]const u8, null), diagnostic.sensitive_detail);
}
