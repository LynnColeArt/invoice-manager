const std = @import("std");
const persistence = @import("persistence");
const RowView = persistence.RowView;

fn path(allocator: std.mem.Allocator, tmp: *std.testing.TmpDir, name: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/{s}.shovel", .{ tmp.sub_path, name });
}

fn success(_: *anyopaque, executor: persistence.Executor) !void {
    _ = try executor.execute("CREATE TABLE coverage_probe (body TEXT);");
}

fn failure(_: *anyopaque, executor: persistence.Executor) !void {
    _ = try executor.execute("CREATE TABLE coverage_probe (body TEXT);");
    return error.CoverageCallbackFailure;
}

fn startupSuccess(_: *anyopaque, executor: persistence.StartupExecutor) !void {
    _ = try executor.execute("CREATE TABLE coverage_probe (body TEXT);");
}

fn startupFailure(_: *anyopaque, executor: persistence.StartupExecutor) !void {
    _ = try executor.execute("CREATE TABLE coverage_probe (body TEXT);");
    return error.CoverageCallbackFailure;
}

fn insert(_: *anyopaque, executor: persistence.Executor) !void {
    _ = try executor.executeText("INSERT INTO coverage_probe VALUES (", "coverage", ");");
}

fn startupInsert(_: *anyopaque, executor: persistence.StartupExecutor) !void {
    _ = try executor.executeText("INSERT INTO coverage_probe VALUES (", "coverage", ");");
}

fn selectRows(_: *anyopaque, executor: persistence.Executor) !void {
    const result = try executor.execute("SELECT body FROM coverage_probe;");
    try std.testing.expectEqual(@as(usize, 1), result.row_count);
}

fn statementFailure(_: *anyopaque, executor: persistence.Executor) !void {
    _ = try executor.execute("SELECT FROM invalid_coverage_statement;");
}

const RichContext = struct {
    visits: usize = 0,
    denied: bool = false,
};

fn visitRich(raw_context: *anyopaque, row: *const RowView) !void {
    const context: *RichContext = @ptrCast(@alignCast(raw_context));
    _ = row.len();
    _ = try row.value(0);
    _ = try row.value(1);
    _ = try row.value(2);
    _ = try row.value(3);
    _ = try row.value(4);
    _ = try row.value(5);
    _ = row.value(6) catch {};
    context.visits += 1;
}

fn richNormal(raw_context: *anyopaque, executor: persistence.Executor) !void {
    const context: *RichContext = @ptrCast(@alignCast(raw_context));
    _ = try executor.execute(
        "CREATE TABLE coverage_rich (id INTEGER, score FLOAT, active BOOLEAN, body TEXT, embedding VECTOR(2));",
    );
    _ = try executor.executeBound(
        &.{ "INSERT INTO coverage_rich VALUES (1, 1.5, TRUE, ", ", [0.25, 0.75]);" },
        &.{"coverage"},
    );
    _ = try executor.query(
        "SELECT NULL, id, score, active, body, embedding FROM coverage_rich;",
        .{ .context = context, .visit = visitRich },
    );
    _ = try executor.queryBound(
        &.{ "SELECT NULL, id, score, active, body, embedding FROM coverage_rich WHERE body = ", ";" },
        &.{"coverage"},
        .{ .context = context, .visit = visitRich },
    );
    _ = executor.execute("SELECT FROM sql-sentinel-DO-NOT-LEAK;") catch {};
    _ = executor.execute("SELECT body FROM coverage_missing;") catch {};
    _ = executor.executeBound(&.{"SELECT id FROM coverage_rich WHERE body = "}, &.{"coverage"}) catch {};
    _ = executor.executeBound(&.{ "SELECT id FROM coverage_rich WHERE body = ", ";" }, &.{"nul\x00value"}) catch {};
    _ = executor.query(
        "CREATE TABLE coverage_rows_required (body TEXT);",
        .{ .context = context, .visit = visitRich },
    ) catch {};
    const forged: persistence.StartupExecutor = @enumFromInt(@intFromEnum(executor));
    _ = forged.executeScript("CREATE TABLE coverage_denied (body TEXT);") catch |err| {
        if (err == error.CapabilityDenied) context.denied = true;
    };
}

fn richStartup(raw_context: *anyopaque, executor: persistence.StartupExecutor) !void {
    const context: *RichContext = @ptrCast(@alignCast(raw_context));
    _ = try executor.executeScript(
        "CREATE TABLE coverage_startup_rich (id INTEGER, score FLOAT, active BOOLEAN, body TEXT, embedding VECTOR(2));\n",
    );
    _ = try executor.executeBound(
        &.{ "INSERT INTO coverage_startup_rich VALUES (1, 1.5, TRUE, ", ", [0.25, 0.75]);" },
        &.{"coverage"},
    );
    _ = try executor.query(
        "SELECT NULL, id, score, active, body, embedding FROM coverage_startup_rich;",
        .{ .context = context, .visit = visitRich },
    );
    _ = try executor.queryBound(
        &.{ "SELECT NULL, id, score, active, body, embedding FROM coverage_startup_rich WHERE body = ", ";" },
        &.{"coverage"},
        .{ .context = context, .visit = visitRich },
    );
    _ = executor.executeScript("CREATE TABLE coverage_nul (body TEXT);\x00") catch {};
    _ = executor.executeScript("CREATE TABLE coverage_one (body TEXT); CREATE TABLE coverage_two (body TEXT);") catch {};
    const forged: persistence.Executor = @enumFromInt(@intFromEnum(executor));
    _ = forged.execute("SELECT id FROM coverage_startup_rich;") catch |err| {
        if (err == error.CapabilityDenied) context.denied = true;
    };
}

fn noOp(_: *anyopaque, _: persistence.Executor) !void {}

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

const coverage_pause = std.Io.Clock.Duration{
    .raw = .fromMilliseconds(1),
    .clock = .awake,
};

fn waitForAtomic(flag: *std.atomic.Value(bool)) !void {
    const deadline = std.Io.Clock.Timestamp.fromNow(std.testing.io, .{
        .raw = .fromSeconds(1),
        .clock = .awake,
    });
    while (!flag.load(.acquire)) {
        if (std.Io.Clock.Timestamp.now(std.testing.io, .awake).compare(.gte, deadline)) return error.TestTimeout;
        try coverage_pause.sleep(std.testing.io);
    }
}

fn waitForExecutorClosing(barrier: *persistence.testing.ExecutorCallBarrier) !void {
    const deadline = std.Io.Clock.Timestamp.fromNow(std.testing.io, .{
        .raw = .fromSeconds(1),
        .clock = .awake,
    });
    while (!barrier.hasClosing()) {
        if (std.Io.Clock.Timestamp.now(std.testing.io, .awake).compare(.gte, deadline)) return error.TestTimeout;
        try coverage_pause.sleep(std.testing.io);
    }
}

const ClosingContext = struct {
    entered: std.atomic.Value(bool) = .init(false),
    release: std.atomic.Value(bool) = .init(false),
    result: ?anyerror = null,
};

const RetainContext = struct {
    executor: ?persistence.Executor = null,
    barrier: *persistence.testing.ExecutorCallBarrier,
    helper: ?std.Thread = null,
    helper_result: ?anyerror = null,
    result: ?anyerror = null,
};

fn admittedExecutorCall(context: *RetainContext, executor: persistence.Executor) void {
    _ = executor.execute("CREATE TABLE coverage_admitted (body TEXT);") catch |err| {
        context.helper_result = err;
    };
}

fn retainExecutor(raw_context: *anyopaque, executor: persistence.Executor) !void {
    const context: *RetainContext = @ptrCast(@alignCast(raw_context));
    context.executor = executor;
    context.helper = try std.Thread.spawn(.{}, admittedExecutorCall, .{ context, executor });
    const deadline = std.Io.Clock.Timestamp.fromNow(std.testing.io, .{
        .raw = .fromSeconds(1),
        .clock = .awake,
    });
    while (!context.barrier.hasAdmitted()) {
        if (std.Io.Clock.Timestamp.now(std.testing.io, .awake).compare(.gte, deadline)) {
            return error.TestTimeout;
        }
        try coverage_pause.sleep(std.testing.io);
    }
}

fn retainedMutation(store: *persistence.Store, context: *RetainContext) void {
    _ = store.mutate(.{ .context = context, .run = retainExecutor }) catch |err| {
        context.result = err;
    };
}

fn blockedMutation(raw: *anyopaque, _: persistence.Executor) !void {
    const context: *ClosingContext = @ptrCast(@alignCast(raw));
    context.entered.store(true, .release);
    try waitForAtomic(&context.release);
}

fn mutationThread(store: *persistence.Store, context: *ClosingContext) void {
    _ = store.mutate(.{ .context = context, .run = blockedMutation }) catch |err| {
        context.result = err;
        return;
    };
}

const ShutdownAttempt = struct {
    store: *persistence.Store,
    result: ?anyerror = null,
    done: std.atomic.Value(bool) = .init(false),

    fn run(self: *ShutdownAttempt) void {
        self.store.shutdown() catch |err| {
            self.result = err;
        };
        self.done.store(true, .release);
    }
};

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
    _ = try store.startupWrite(.{ .context = &unused, .run = startupInsert });
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
    try std.testing.expectError(error.StoreClosed, store.startupWrite(.{ .context = &unused, .run = startupSuccess }));
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
    try std.testing.expectError(error.StartupWriteFailed, store.startupWrite(.{ .context = &unused, .run = startupFailure }));
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
    try std.testing.expectError(error.StartupWriteFailed, startup_store.startupWrite(.{ .context = &unused, .run = startupSuccess }));
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
    try std.testing.expectError(error.TransactionBeginFailed, begin_store.startupWrite(.{ .context = &unused, .run = startupSuccess }));
    try std.testing.expectEqual(persistence.State.ready, begin_store.state());

    const registration_path = try path(allocator, &tmp, "executor-registration");
    defer allocator.free(registration_path);
    var registration_store = try persistence.testing.openWithFaults(
        allocator,
        std.testing.io,
        registration_path,
        .{ .executor_registration = true },
    );
    defer registration_store.shutdown() catch {};
    try std.testing.expectError(error.OutOfMemory, registration_store.mutate(.{ .context = &unused, .run = success }));
    persistence.testing.setFaults(&registration_store, .{});
    _ = try registration_store.mutate(.{ .context = &unused, .run = success });

    const startup_registration_path = try path(allocator, &tmp, "startup-executor-registration");
    defer allocator.free(startup_registration_path);
    var startup_registration_store = try persistence.testing.openWithFaults(
        allocator,
        std.testing.io,
        startup_registration_path,
        .{ .executor_registration = true },
    );
    defer startup_registration_store.shutdown() catch {};
    try std.testing.expectError(
        error.StartupWriteFailed,
        startup_registration_store.startupWrite(.{ .context = &unused, .run = startupSuccess }),
    );
    try std.testing.expectEqual(@as(usize, 1), persistence.testing.discardCount(&startup_registration_store));
    try std.testing.expectEqual(@as(usize, 1), persistence.testing.reopenCount(&startup_registration_store));
}

test "hard-link identity rejection and inspection cleanup use the public open boundary" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try path(allocator, &tmp, "coverage-hard-link");
    defer allocator.free(database_path);
    const alias_path = try path(allocator, &tmp, "coverage-hard-link-alias");
    defer allocator.free(alias_path);

    var created = try persistence.Store.open(allocator, std.testing.io, database_path);
    try created.shutdown();
    try std.Io.Dir.hardLink(.cwd(), database_path, .cwd(), alias_path, std.testing.io, .{});
    try std.testing.expectError(error.LeaseConflict, persistence.Store.open(allocator, std.testing.io, database_path));
    try std.testing.expectError(error.LeaseConflict, persistence.Store.open(allocator, std.testing.io, alias_path));
    try std.Io.Dir.deleteFile(.cwd(), std.testing.io, alias_path);

    try std.testing.expectError(
        error.LeaseAcquireFailed,
        persistence.testing.openWithFaults(
            allocator,
            std.testing.io,
            database_path,
            .{ .identity_inspection = true },
        ),
    );
    try std.testing.expectError(
        error.OutOfMemory,
        persistence.testing.openWithFaults(
            allocator,
            std.testing.io,
            database_path,
            .{ .registration = true },
        ),
    );
    var reopened = try persistence.Store.open(allocator, std.testing.io, database_path);
    try reopened.shutdown();
}

test "opaque nonce capabilities reject forged tags and retain terminal diagnostics" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try path(allocator, &tmp, "coverage-capability");
    defer allocator.free(database_path);
    var store = try persistence.testing.openWithFaults(
        allocator,
        std.testing.io,
        database_path,
        .{ .checkpoint = true },
    );
    try std.testing.expect(@intFromEnum(store) > std.math.maxInt(usize));
    var unused: void = {};
    try std.testing.expectError(error.CheckpointFailed, store.mutate(.{ .context = &unused, .run = success }));
    persistence.testing.setFaults(&store, .{});
    try std.testing.expectError(error.StoreQuarantined, store.mutate(.{ .context = &unused, .run = success }));
    try store.shutdown();
    try store.shutdown();
    try std.testing.expectEqual(persistence.State.closed, store.state());
    try std.testing.expectEqual(persistence.DiagnosticCategory.checkpoint_failure, store.lastDiagnostic().?.category);

    var forged: persistence.Store = @enumFromInt(1);
    try std.testing.expectEqual(persistence.State.closed, forged.state());
    try std.testing.expectEqual(@as(?persistence.Diagnostic, null), forged.lastDiagnostic());
    try std.testing.expectError(error.StoreClosed, forged.mutate(.{ .context = &unused, .run = success }));
    try forged.shutdown();
}

test "closing admission rejects observers and mutations while admitted work drains" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try path(allocator, &tmp, "coverage-closing");
    defer allocator.free(database_path);
    var shutdown_barrier = persistence.testing.ShutdownCallBarrier{};
    var store = try persistence.testing.openWithFaults(
        allocator,
        std.testing.io,
        database_path,
        .{ .shutdown = true, .shutdown_call_barrier = &shutdown_barrier },
    );
    var context = ClosingContext{};
    const mutation = try std.Thread.spawn(.{}, mutationThread, .{ &store, &context });
    try waitForAtomic(&context.entered);

    var first_attempt = ShutdownAttempt{ .store = &store };
    const first_shutdown = try std.Thread.spawn(.{}, ShutdownAttempt.run, .{&first_attempt});
    try shutdown_barrier.waitForCallers(1, std.testing.io);
    var second_attempt = ShutdownAttempt{ .store = &store };
    const second_shutdown = try std.Thread.spawn(.{}, ShutdownAttempt.run, .{&second_attempt});
    try shutdown_barrier.waitForCallers(2, std.testing.io);
    try std.testing.expect(!first_attempt.done.load(.acquire));
    try std.testing.expect(!second_attempt.done.load(.acquire));
    var unused: void = {};
    try std.testing.expectError(error.StoreClosed, store.mutate(.{ .context = &unused, .run = success }));
    try std.testing.expectEqual(@as(?persistence.Diagnostic, null), store.lastDiagnostic());
    context.release.store(true, .release);
    mutation.join();
    first_shutdown.join();
    second_shutdown.join();
    try std.testing.expectEqual(@as(?anyerror, null), context.result);
    try std.testing.expectEqual(@as(?anyerror, error.ShutdownFailed), first_attempt.result);
    try std.testing.expectEqual(@as(?anyerror, error.ShutdownFailed), second_attempt.result);
    try std.testing.expect(shutdown_barrier.hasReclaimed());
    try std.testing.expectError(error.ShutdownFailed, store.shutdown());
    try std.testing.expectEqual(persistence.State.closed, store.state());
    try std.testing.expectEqual(persistence.DiagnosticCategory.shutdown_failure, store.lastDiagnostic().?.category);
}

test "executor capabilities cover bound rows safe categories and startup runtime scripts" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try path(allocator, &tmp, "coverage-executors");
    defer allocator.free(database_path);
    var store = try persistence.Store.open(allocator, std.testing.io, database_path);
    defer store.shutdown() catch {};

    var normal_context = RichContext{};
    _ = try store.mutate(.{ .context = &normal_context, .run = richNormal });
    try std.testing.expect(normal_context.visits >= 2);
    try std.testing.expect(normal_context.denied);

    var startup_context = RichContext{};
    _ = try store.startupWrite(.{ .context = &startup_context, .run = richStartup });
    try std.testing.expect(startup_context.visits >= 2);
    try std.testing.expect(startup_context.denied);
}

test "durability completion covers committed checkpointed quarantined and ineligible states" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var unused: void = {};

    const checkpoint_path = try path(allocator, &tmp, "coverage-complete-checkpoint");
    defer allocator.free(checkpoint_path);
    var checkpoint_store = try persistence.testing.openWithFaults(
        allocator,
        std.testing.io,
        checkpoint_path,
        .{ .checkpoint = true },
    );
    defer checkpoint_store.shutdown() catch {};
    try std.testing.expectError(error.CheckpointFailed, checkpoint_store.mutate(.{ .context = &unused, .run = noOp }));
    persistence.testing.setFaults(&checkpoint_store, .{});
    try std.testing.expectError(error.StoreQuarantined, checkpoint_store.mutate(.{ .context = &unused, .run = noOp }));
    _ = try checkpoint_store.completeDurability();
    try std.testing.expectError(error.DurabilityCompletionUnavailable, checkpoint_store.completeDurability());

    const sync_path = try path(allocator, &tmp, "coverage-complete-sync");
    defer allocator.free(sync_path);
    var sync_store = try persistence.testing.openWithFaults(
        allocator,
        std.testing.io,
        sync_path,
        .{ .directory_sync = true },
    );
    defer sync_store.shutdown() catch {};
    try std.testing.expectError(error.DirectorySyncFailed, sync_store.mutate(.{ .context = &unused, .run = noOp }));
    persistence.testing.setFaults(&sync_store, .{});
    _ = try sync_store.completeDurability();

    const commit_path = try path(allocator, &tmp, "coverage-complete-commit");
    defer allocator.free(commit_path);
    var commit_store = try persistence.testing.openWithFaults(
        allocator,
        std.testing.io,
        commit_path,
        .{ .commit = true },
    );
    defer commit_store.shutdown() catch {};
    try std.testing.expectError(error.CommitFailed, commit_store.mutate(.{ .context = &unused, .run = noOp }));
    try std.testing.expectError(error.DurabilityCompletionUnavailable, commit_store.completeDurability());
}

test "callback-scoped executor drains admitted calls and rejects retained values" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try path(allocator, &tmp, "coverage-expiry");
    defer allocator.free(database_path);
    var barrier = persistence.testing.ExecutorCallBarrier{};
    var store = try persistence.testing.openWithFaults(
        allocator,
        std.testing.io,
        database_path,
        .{ .executor_call_barrier = &barrier },
    );
    defer store.shutdown() catch {};
    var context = RetainContext{ .barrier = &barrier };
    const thread = try std.Thread.spawn(.{}, retainedMutation, .{ &store, &context });
    var joined = false;
    var helper_joined = false;
    defer {
        barrier.allow();
        if (!joined) thread.join();
        if (!helper_joined) {
            if (context.helper) |helper| helper.join();
        }
    }
    try waitForExecutorClosing(&barrier);
    try std.testing.expectError(
        error.CapabilityDenied,
        context.executor.?.execute("CREATE TABLE coverage_expired (body TEXT);"),
    );
    barrier.allow();
    context.helper.?.join();
    helper_joined = true;
    thread.join();
    joined = true;
    try std.testing.expectEqual(@as(?anyerror, null), context.helper_result);
    try std.testing.expectEqual(@as(?anyerror, null), context.result);
    try std.testing.expectEqual(
        @as(usize, 0),
        try persistence.testing.rowCount(&store, "SELECT body FROM coverage_admitted;"),
    );
    try std.testing.expectError(
        error.CapabilityDenied,
        context.executor.?.execute("CREATE TABLE coverage_expired_after_receipt (body TEXT);"),
    );
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
    try std.testing.expectError(error.DirtyDiscardFailed, store.startupWrite(.{ .context = &unused, .run = startupFailure }));
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
    try std.testing.expectError(error.ReopenFailed, store.startupWrite(.{ .context = &unused, .run = startupFailure }));
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
    try std.testing.expectError(error.ReopenFailed, store.startupWrite(.{ .context = &unused, .run = startupFailure }));
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
