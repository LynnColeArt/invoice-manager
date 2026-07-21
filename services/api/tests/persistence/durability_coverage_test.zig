const std = @import("std");
const persistence = @import("persistence");

fn path(allocator: std.mem.Allocator, tmp: *std.testing.TmpDir, name: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/{s}.shovel", .{ tmp.sub_path, name });
}

fn success(_: *anyopaque, executor: *persistence.Executor) !void {
    _ = try executor.execute("CREATE TABLE coverage_probe (body TEXT);");
}

fn failure(_: *anyopaque, executor: *persistence.Executor) !void {
    _ = try executor.execute("CREATE TABLE coverage_probe (body TEXT);");
    return error.CoverageCallbackFailure;
}

fn insert(_: *anyopaque, executor: *persistence.Executor) !void {
    _ = try executor.executeText("INSERT INTO coverage_probe VALUES (", "coverage", ");");
}

fn selectRows(_: *anyopaque, executor: *persistence.Executor) !void {
    const result = try executor.execute("SELECT body FROM coverage_probe;");
    try std.testing.expectEqual(@as(usize, 1), result.row_count);
}

fn statementFailure(_: *anyopaque, executor: *persistence.Executor) !void {
    _ = try executor.execute("SELECT FROM invalid_coverage_statement;");
}

fn expectOpenFault(faults: persistence.testing.Faults, expected: anyerror, name: []const u8) !void {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try path(allocator, &tmp, name);
    defer allocator.free(database_path);
    try std.testing.expectError(expected, persistence.testing.openWithFaults(allocator, std.testing.io, database_path, faults));
}

fn expectMutationFault(faults: persistence.testing.Faults, expected: anyerror, name: []const u8) !void {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try path(allocator, &tmp, name);
    defer allocator.free(database_path);
    var store = try persistence.testing.openWithFaults(allocator, std.testing.io, database_path, faults);
    defer store.shutdown() catch {};
    var unused: void = {};
    try std.testing.expectError(expected, store.mutate(.{ .context = &unused, .run = success }));
    try std.testing.expect(store.lastDiagnostic() != null);
}

test "persistence production declarations are analyzed" {
    std.testing.refAllDecls(persistence);
}

test "successful facade covers durable receipt queries and idempotent shutdown" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try path(allocator, &tmp, "successful-facade");
    defer allocator.free(database_path);
    var store = try persistence.Store.open(allocator, std.testing.io, database_path);
    try std.testing.expectEqual(persistence.State.ready, store.state());
    try std.testing.expectEqual(@as(?persistence.Diagnostic, null), store.lastDiagnostic());
    try std.testing.expectError(
        error.QueryFailed,
        persistence.testing.rowCount(&store, "SELECT body FROM coverage_probe;"),
    );
    var unused: void = {};
    const created = try store.mutate(.{ .context = &unused, .run = success });
    try std.testing.expectEqual(persistence.State.directory_synchronized, created.durability);
    _ = try store.startupWrite(.{ .context = &unused, .run = insert });
    _ = try store.mutate(.{ .context = &unused, .run = selectRows });
    try std.testing.expectEqual(@as(usize, 1), try persistence.testing.rowCount(&store, "SELECT body FROM coverage_probe;"));
    try std.testing.expect(persistence.testing.checkpointCount(&store) >= 3);
    try std.testing.expectEqual(@as(usize, 0), persistence.testing.discardCount(&store));
    try std.testing.expectEqual(@as(usize, 0), persistence.testing.reopenCount(&store));
    try std.testing.expectEqual(@as(usize, 0), persistence.testing.openDirectoryCount(&store));
    try std.testing.expect(persistence.testing.receiptIssued(&store));
    try std.testing.expect(persistence.testing.events(&store).len > 0);
    try store.shutdown();
    try store.shutdown();
    try std.testing.expectEqual(persistence.State.closed, store.state());
    try std.testing.expectEqual(@as(?persistence.Diagnostic, null), store.lastDiagnostic());
    try std.testing.expectEqual(@as(usize, 0), persistence.testing.checkpointCount(&store));
    try std.testing.expectEqual(@as(usize, 0), persistence.testing.discardCount(&store));
    try std.testing.expectEqual(@as(usize, 0), persistence.testing.reopenCount(&store));
    try std.testing.expectEqual(@as(usize, 0), persistence.testing.openDirectoryCount(&store));
    try std.testing.expect(!persistence.testing.receiptIssued(&store));
    try std.testing.expectEqual(@as(usize, 0), persistence.testing.events(&store).len);
    persistence.testing.setFaults(&store, .{});
    try std.testing.expectError(error.StoreClosed, persistence.testing.rowCount(&store, "SELECT body FROM coverage_probe;"));
    try std.testing.expectError(error.StoreClosed, store.mutate(.{ .context = &unused, .run = success }));
    try std.testing.expectError(error.StoreClosed, store.startupWrite(.{ .context = &unused, .run = success }));
}

test "startup callback failure performs successful discard and reopen" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try path(allocator, &tmp, "startup-recovery");
    defer allocator.free(database_path);
    var store = try persistence.Store.open(allocator, std.testing.io, database_path);
    defer store.shutdown() catch {};
    var unused: void = {};
    try std.testing.expectError(error.StartupWriteFailed, store.startupWrite(.{ .context = &unused, .run = failure }));
    try std.testing.expectEqual(persistence.State.ready, store.state());
    try std.testing.expectEqual(@as(usize, 1), persistence.testing.discardCount(&store));
    try std.testing.expectEqual(@as(usize, 1), persistence.testing.reopenCount(&store));
}

test "existing canonical paths and real statement errors retain ownership" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try path(allocator, &tmp, "existing-path");
    defer allocator.free(database_path);
    var store = try persistence.Store.open(allocator, std.testing.io, database_path);
    var unused: void = {};
    try std.testing.expectError(error.CallbackFailed, store.mutate(.{ .context = &unused, .run = insert }));
    try std.testing.expectError(error.CallbackFailed, store.mutate(.{ .context = &unused, .run = selectRows }));
    _ = try store.mutate(.{ .context = &unused, .run = success });
    try std.testing.expectError(error.CallbackFailed, store.mutate(.{ .context = &unused, .run = success }));
    try std.testing.expectError(error.CallbackFailed, store.mutate(.{ .context = &unused, .run = statementFailure }));
    try store.shutdown();
    store = try persistence.Store.open(allocator, std.testing.io, database_path);
    try store.shutdown();
}

test "canonicalization and open failures cover real operating-system boundaries" {
    const allocator = std.testing.allocator;
    try expectOpenFault(.{ .canonicalization = true }, error.CanonicalizationFailed, "canonicalization-injected");
    try std.testing.expectError(error.CanonicalizationFailed, persistence.Store.open(allocator, std.testing.io, ""));
    try std.testing.expectError(error.CanonicalizationFailed, persistence.Store.open(allocator, std.testing.io, "wp06-missing-parent/."));
    try std.testing.expectError(error.CanonicalizationFailed, persistence.Store.open(allocator, std.testing.io, "wp06-missing-parent/.."));
    try std.testing.expectError(error.LeaseAcquireFailed, persistence.Store.open(allocator, std.testing.io, "/proc/self/status"));

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const non_directory = try path(allocator, &tmp, "not-a-directory");
    defer allocator.free(non_directory);
    const file = try std.Io.Dir.createFile(.cwd(), std.testing.io, non_directory, .{});
    file.close(std.testing.io);
    const child = try std.fmt.allocPrint(allocator, "{s}/child.shovel", .{non_directory});
    defer allocator.free(child);
    try std.testing.expectError(error.CanonicalizationFailed, persistence.Store.open(allocator, std.testing.io, child));

    const directory_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}", .{tmp.sub_path});
    defer allocator.free(directory_path);
    try std.testing.expectError(error.EngineOpenFailed, persistence.Store.open(allocator, std.testing.io, directory_path));
}

test "injected callback and startup begin failures preserve typed recovery states" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const callback_path = try path(allocator, &tmp, "injected-callback");
    defer allocator.free(callback_path);
    var callback_store = try persistence.testing.openWithFaults(
        allocator,
        std.testing.io,
        callback_path,
        .{ .callback = true },
    );
    defer callback_store.shutdown() catch {};
    var unused: void = {};
    try std.testing.expectError(error.CallbackFailed, callback_store.mutate(.{ .context = &unused, .run = success }));
    try std.testing.expectEqual(persistence.State.ready, callback_store.state());
    try std.testing.expectEqual(persistence.DiagnosticCategory.callback_failure, callback_store.lastDiagnostic().?.category);

    const startup_path = try path(allocator, &tmp, "startup-callback");
    defer allocator.free(startup_path);
    var startup_store = try persistence.testing.openWithFaults(
        allocator,
        std.testing.io,
        startup_path,
        .{ .callback = true },
    );
    defer startup_store.shutdown() catch {};
    try std.testing.expectError(error.StartupWriteFailed, startup_store.startupWrite(.{ .context = &unused, .run = success }));
    try std.testing.expectEqual(persistence.State.ready, startup_store.state());
    try std.testing.expectEqual(@as(usize, 1), persistence.testing.discardCount(&startup_store));
    try std.testing.expectEqual(@as(usize, 1), persistence.testing.reopenCount(&startup_store));

    const begin_path = try path(allocator, &tmp, "startup-begin");
    defer allocator.free(begin_path);
    var begin_store = try persistence.testing.openWithFaults(
        allocator,
        std.testing.io,
        begin_path,
        .{ .transaction_begin = true },
    );
    defer begin_store.shutdown() catch {};
    try std.testing.expectError(error.TransactionBeginFailed, begin_store.startupWrite(.{ .context = &unused, .run = success }));
    try std.testing.expectEqual(persistence.State.ready, begin_store.state());
}

test "critical branch: canonicalization_failure" {
    try std.testing.expectError(error.CanonicalizationFailed, persistence.Store.open(std.testing.allocator, std.testing.io, "\x00"));
}
test "critical branch: lease_acquire_failure" {
    try expectOpenFault(.{ .lease_acquire = true }, error.LeaseAcquireFailed, "lease-acquire");
}
test "critical branch: lease_conflict" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try path(allocator, &tmp, "lease-conflict");
    defer allocator.free(database_path);
    var store = try persistence.Store.open(allocator, std.testing.io, database_path);
    defer store.shutdown() catch {};
    try std.testing.expectError(error.LeaseConflict, persistence.Store.open(allocator, std.testing.io, database_path));
}
test "critical branch: engine_open_failure" {
    try expectOpenFault(.{ .engine_open = true }, error.EngineOpenFailed, "engine-open");
}
test "critical branch: partial_open_cleanup" {
    try expectOpenFault(.{ .engine_open = true }, error.EngineOpenFailed, "partial-cleanup");
}
test "critical branch: transaction_begin_failure" {
    try expectMutationFault(.{ .transaction_begin = true }, error.TransactionBeginFailed, "begin");
}
test "critical branch: callback_failure" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try path(allocator, &tmp, "callback");
    defer allocator.free(database_path);
    var store = try persistence.Store.open(allocator, std.testing.io, database_path);
    defer store.shutdown() catch {};
    var unused: void = {};
    try std.testing.expectError(error.CallbackFailed, store.mutate(.{ .context = &unused, .run = failure }));
}
test "critical branch: rollback_failure" {
    try expectMutationFault(.{ .callback = true, .rollback = true }, error.RollbackFailed, "rollback");
}
test "critical branch: commit_failure" {
    try expectMutationFault(.{ .commit = true }, error.CommitFailed, "commit");
}
test "critical branch: checkpoint_failure" {
    try expectMutationFault(.{ .checkpoint = true }, error.CheckpointFailed, "checkpoint");
}
test "critical branch: directory_open_failure" {
    try expectMutationFault(.{ .directory_open = true }, error.DirectoryOpenFailed, "directory-open");
}
test "critical branch: directory_sync_failure" {
    try expectMutationFault(.{ .directory_sync = true }, error.DirectorySyncFailed, "directory-sync");
}
test "critical branch: directory_close_failure" {
    try expectMutationFault(.{ .directory_close = true }, error.DirectoryCloseFailed, "directory-close");
}
test "critical branch: uncertain_transition" {
    try expectMutationFault(.{ .checkpoint = true }, error.CheckpointFailed, "uncertain");
}
test "critical branch: quarantined_refusal" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try path(allocator, &tmp, "quarantined");
    defer allocator.free(database_path);
    var store = try persistence.testing.openWithFaults(allocator, std.testing.io, database_path, .{ .checkpoint = true });
    defer store.shutdown() catch {};
    var unused: void = {};
    try std.testing.expectError(error.CheckpointFailed, store.mutate(.{ .context = &unused, .run = success }));
    persistence.testing.setFaults(&store, .{});
    try std.testing.expectError(error.StoreQuarantined, store.mutate(.{ .context = &unused, .run = success }));
}
test "critical branch: dirty_discard_failure" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try path(allocator, &tmp, "discard");
    defer allocator.free(database_path);
    var store = try persistence.testing.openWithFaults(allocator, std.testing.io, database_path, .{ .dirty_discard = true });
    defer store.shutdown() catch {};
    var unused: void = {};
    try std.testing.expectError(error.DirtyDiscardFailed, store.startupWrite(.{ .context = &unused, .run = failure }));
}
test "critical branch: reopen_failure" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try path(allocator, &tmp, "reopen");
    defer allocator.free(database_path);
    var store = try persistence.testing.openWithFaults(allocator, std.testing.io, database_path, .{ .reopen = true });
    defer store.shutdown() catch {};
    var unused: void = {};
    try std.testing.expectError(error.ReopenFailed, store.startupWrite(.{ .context = &unused, .run = failure }));
}
test "critical branch: recovery_quarantine" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try path(allocator, &tmp, "recovery-quarantine");
    defer allocator.free(database_path);
    var store = try persistence.testing.openWithFaults(allocator, std.testing.io, database_path, .{ .reopen = true });
    defer store.shutdown() catch {};
    var unused: void = {};
    try std.testing.expectError(error.ReopenFailed, store.startupWrite(.{ .context = &unused, .run = failure }));
    try std.testing.expectEqual(persistence.State.quarantined, store.state());
}
test "critical branch: unsupported_directory_sync" {
    try expectMutationFault(.{ .unsupported_directory_sync = true }, error.UnsupportedDirectorySync, "unsupported-sync");
}
test "critical branch: shutdown_failure" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try path(allocator, &tmp, "shutdown");
    defer allocator.free(database_path);
    var store = try persistence.testing.openWithFaults(allocator, std.testing.io, database_path, .{ .shutdown = true });
    try std.testing.expectError(error.ShutdownFailed, store.shutdown());
    try std.testing.expectEqual(persistence.State.closed, store.state());
}
