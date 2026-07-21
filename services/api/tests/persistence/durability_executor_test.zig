const std = @import("std");
const persistence = @import("persistence");

fn databasePath(allocator: std.mem.Allocator, tmp: *const std.testing.TmpDir, suffix: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/{s}.shovel", .{ tmp.sub_path, suffix });
}

const HistoryContext = struct {
    visited: usize = 0,
    bounds_rejected: bool = false,
};

fn inspectHistory(raw_context: *anyopaque, row: *const persistence.RowView) !void {
    const context: *HistoryContext = @ptrCast(@alignCast(raw_context));
    try std.testing.expectEqual(@as(usize, 5), row.len());
    try std.testing.expectEqualStrings("018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f", (try row.value(0)).text);
    try std.testing.expectEqualStrings("owner's-team", (try row.value(1)).text);
    try std.testing.expectEqualStrings("descriptor-digest", (try row.value(2)).text);
    try std.testing.expectEqualStrings("script-digest", (try row.value(3)).text);
    try std.testing.expectEqualStrings("2026-07-20T12:34:56.789Z", (try row.value(4)).text);
    try std.testing.expectError(error.RowIndexOutOfBounds, row.value(5));
    context.bounds_rejected = true;
    context.visited += 1;
}

fn bindAndQuery(raw_context: *anyopaque, executor: persistence.Executor) !void {
    const context: *HistoryContext = @ptrCast(@alignCast(raw_context));
    _ = try executor.execute(
        "CREATE TABLE wp06_history (id TEXT, owner TEXT, descriptor_digest TEXT, script_digest TEXT, applied_at TEXT);",
    );
    _ = try executor.executeBound(
        &.{
            "INSERT INTO wp06_history VALUES (",
            ", ",
            ", ",
            ", ",
            ", ",
            ");",
        },
        &.{
            "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f",
            "owner's-team",
            "descriptor-digest",
            "script-digest",
            "2026-07-20T12:34:56.789Z",
        },
    );
    const count = try executor.query(
        "SELECT id, owner, descriptor_digest, script_digest, applied_at FROM wp06_history;",
        .{ .context = context, .visit = inspectHistory },
    );
    try std.testing.expectEqual(@as(usize, 1), count);
    const filtered_count = try executor.queryBound(
        &.{
            "SELECT id, owner, descriptor_digest, script_digest, applied_at FROM wp06_history WHERE owner = ",
            ";",
        },
        &.{"owner's-team"},
        .{ .context = context, .visit = inspectHistory },
    );
    try std.testing.expectEqual(@as(usize, 1), filtered_count);
}

test "opaque executor supports multiple bound values and application-neutral row visits" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(allocator, &tmp, "bound-query");
    defer allocator.free(path);
    var store = try persistence.Store.open(allocator, std.testing.io, path);
    defer store.shutdown() catch {};

    var context = HistoryContext{};
    _ = try store.mutate(.{ .context = &context, .run = bindAndQuery });
    try std.testing.expectEqual(@as(usize, 2), context.visited);
    try std.testing.expect(context.bounds_rejected);
}

const ValueContext = struct {
    visited: bool = false,
};

fn inspectNeutralValues(raw_context: *anyopaque, row: *const persistence.RowView) !void {
    const context: *ValueContext = @ptrCast(@alignCast(raw_context));
    try std.testing.expectEqual(@as(usize, 6), row.len());
    try std.testing.expect(switch (try row.value(0)) {
        .null_value => true,
        else => false,
    });
    try std.testing.expectEqual(@as(i64, 7), (try row.value(1)).integer);
    try std.testing.expectEqual(@as(f64, 1.5), (try row.value(2)).float);
    try std.testing.expect((try row.value(3)).boolean);
    try std.testing.expectEqualStrings("neutral", (try row.value(4)).text);
    try std.testing.expectEqualSlices(f32, &.{ 0.25, 0.75 }, (try row.value(5)).vector_f32);
    context.visited = true;
}

fn queryNeutralValues(raw_context: *anyopaque, executor: persistence.Executor) !void {
    const context: *ValueContext = @ptrCast(@alignCast(raw_context));
    _ = try executor.execute(
        "CREATE TABLE wp06_values (id INTEGER, score FLOAT, active BOOLEAN, body TEXT, embedding VECTOR(2));",
    );
    _ = try executor.execute("INSERT INTO wp06_values VALUES (7, 1.5, TRUE, 'neutral', [0.25, 0.75]);");
    const count = try executor.query(
        "SELECT NULL, id, score, active, body, embedding FROM wp06_values;",
        .{ .context = context, .visit = inspectNeutralValues },
    );
    try std.testing.expectEqual(@as(usize, 1), count);
}

test "row views translate copied engine values into neutral value tags" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(allocator, &tmp, "neutral-values");
    defer allocator.free(path);
    var store = try persistence.Store.open(allocator, std.testing.io, path);
    defer store.shutdown() catch {};

    var context = ValueContext{};
    _ = try store.mutate(.{ .context = &context, .run = queryNeutralValues });
    try std.testing.expect(context.visited);
}

const CategoryContext = struct {
    parse_failure: bool = false,
    object_failure: bool = false,
    binding_arity_failure: bool = false,
    rows_required: bool = false,
    unexpected: ?anyerror = null,
};

fn unexpectedRow(_: *anyopaque, _: *const persistence.RowView) !void {
    return error.UnexpectedRow;
}

fn classifyStatementFailures(raw_context: *anyopaque, executor: persistence.Executor) !void {
    const context: *CategoryContext = @ptrCast(@alignCast(raw_context));
    _ = executor.execute("SELECT FROM sql-sentinel-DO-NOT-LEAK;") catch |err| switch (err) {
        error.StatementParseFailed => {
            context.parse_failure = true;
        },
        else => {
            context.unexpected = err;
            return;
        },
    };
    _ = executor.execute("SELECT body FROM missing_table;") catch |err| switch (err) {
        error.StatementObjectFailed => {
            context.object_failure = true;
        },
        else => {
            context.unexpected = err;
            return;
        },
    };
    _ = executor.executeBound(&.{"INSERT INTO missing_table VALUES ("}, &.{"value"}) catch |err| switch (err) {
        error.StatementBindingArityMismatch => {
            context.binding_arity_failure = true;
        },
        else => {
            context.unexpected = err;
            return;
        },
    };
    _ = executor.query(
        "CREATE TABLE wp06_query_requires_rows (body TEXT);",
        .{ .context = context, .visit = unexpectedRow },
    ) catch |err| switch (err) {
        error.StatementRowsRequired => {
            context.rows_required = true;
        },
        else => {
            context.unexpected = err;
            return;
        },
    };
}

test "statement failures preserve safe parse and object categories inside callbacks" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(allocator, &tmp, "statement-categories");
    defer allocator.free(path);
    var store = try persistence.Store.open(allocator, std.testing.io, path);
    defer store.shutdown() catch {};

    var context = CategoryContext{};
    _ = try store.mutate(.{ .context = &context, .run = classifyStatementFailures });
    try std.testing.expectEqual(@as(?anyerror, null), context.unexpected);
    try std.testing.expect(context.parse_failure);
    try std.testing.expect(context.object_failure);
    try std.testing.expect(context.binding_arity_failure);
    try std.testing.expect(context.rows_required);
}

const ScriptContext = struct {
    calls: usize = 0,
    script: []const u8,
};

fn runStartupScript(raw_context: *anyopaque, executor: persistence.StartupExecutor) !void {
    const context: *ScriptContext = @ptrCast(@alignCast(raw_context));
    context.calls += 1;
    _ = try executor.executeScript(context.script);
}

const MigrationStartupContext = struct {
    calls: usize = 0,
    history: HistoryContext = .{},
};

fn runMigrationStartup(raw_context: *anyopaque, executor: persistence.StartupExecutor) !void {
    const context: *MigrationStartupContext = @ptrCast(@alignCast(raw_context));
    context.calls += 1;
    _ = try executor.executeScript(
        "CREATE TABLE wp06_runtime_history (id TEXT, owner TEXT, descriptor_digest TEXT, script_digest TEXT, applied_at TEXT);\n",
    );
    _ = try executor.executeBound(
        &.{
            "INSERT INTO wp06_runtime_history VALUES (",
            ", ",
            ", ",
            ", ",
            ", ",
            ");",
        },
        &.{
            "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f",
            "owner's-team",
            "descriptor-digest",
            "script-digest",
            "2026-07-20T12:34:56.789Z",
        },
    );
    const count = try executor.query(
        "SELECT id, owner, descriptor_digest, script_digest, applied_at FROM wp06_runtime_history;",
        .{ .context = &context.history, .visit = inspectHistory },
    );
    try std.testing.expectEqual(@as(usize, 1), count);
    const filtered_count = try executor.queryBound(
        &.{
            "SELECT id, owner, descriptor_digest, script_digest, applied_at FROM wp06_runtime_history WHERE owner = ",
            ";",
        },
        &.{"owner's-team"},
        .{ .context = &context.history, .visit = inspectHistory },
    );
    try std.testing.expectEqual(@as(usize, 1), filtered_count);
}

const NulContext = struct {
    rejected: bool = false,
    multiple_rejected: bool = false,
};

fn rejectNulScript(raw_context: *anyopaque, executor: persistence.StartupExecutor) !void {
    const context: *NulContext = @ptrCast(@alignCast(raw_context));
    if (executor.executeScript("CREATE TABLE must_not_exist (body TEXT);\x00DROP TABLE must_not_exist;")) |_| {
        return error.ExpectedEmbeddedNulRejection;
    } else |err| switch (err) {
        error.StatementEmbeddedNul => context.rejected = true,
        else => return err,
    }
    if (executor.executeScript("CREATE TABLE first_forbidden (body TEXT); CREATE TABLE second_forbidden (body TEXT);")) |_| {
        return error.ExpectedMultipleStatementRejection;
    } else |err| switch (err) {
        error.StatementParseFailed => context.multiple_rejected = true,
        else => return err,
    }
}

test "startup-only executor runs exact runtime scripts and rejects embedded NUL bytes" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(allocator, &tmp, "runtime-script");
    defer allocator.free(path);
    var store = try persistence.Store.open(allocator, std.testing.io, path);
    defer store.shutdown() catch {};

    var startup_context = MigrationStartupContext{};
    _ = try store.startupWrite(.{ .context = &startup_context, .run = runMigrationStartup });
    try std.testing.expectEqual(@as(usize, 1), startup_context.calls);
    try std.testing.expectEqual(@as(usize, 2), startup_context.history.visited);

    var nul_context = NulContext{};
    _ = try store.startupWrite(.{ .context = &nul_context, .run = rejectNulScript });
    try std.testing.expect(nul_context.rejected);
    try std.testing.expect(nul_context.multiple_rejected);
    try std.testing.expectError(
        error.QueryFailed,
        persistence.testing.rowCount(&store, "SELECT body FROM must_not_exist;"),
    );
}

test "post-commit durability completion never replays the startup script" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(allocator, &tmp, "complete-durability");
    defer allocator.free(path);
    var store = try persistence.testing.openWithFaults(
        allocator,
        std.testing.io,
        path,
        .{ .checkpoint = true },
    );
    defer store.shutdown() catch {};

    var context = ScriptContext{
        .script = "CREATE TABLE wp06_complete_durability (body TEXT);\n",
    };
    try std.testing.expectError(
        error.CheckpointFailed,
        store.startupWrite(.{ .context = &context, .run = runStartupScript }),
    );
    try std.testing.expectEqual(@as(usize, 1), context.calls);
    try std.testing.expectEqual(@as(usize, 0), persistence.testing.checkpointCount(&store));
    persistence.testing.setFaults(&store, .{});
    const receipt = try store.completeDurability();
    try std.testing.expectEqual(persistence.State.directory_synchronized, receipt.durability);
    try std.testing.expectEqual(@as(usize, 1), context.calls);
    try std.testing.expectEqual(@as(usize, 1), persistence.testing.checkpointCount(&store));
    try std.testing.expectEqual(persistence.State.ready, store.state());
    try std.testing.expectEqual(@as(?persistence.Diagnostic, null), store.lastDiagnostic());
    try std.testing.expectEqual(
        @as(usize, 0),
        try persistence.testing.rowCount(&store, "SELECT body FROM wp06_complete_durability;"),
    );
}

test "directory-sync completion retries no checkpoint and never replays the callback" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(allocator, &tmp, "complete-directory-sync");
    defer allocator.free(path);
    var store = try persistence.testing.openWithFaults(
        allocator,
        std.testing.io,
        path,
        .{ .directory_sync = true },
    );
    defer store.shutdown() catch {};

    var context = ScriptContext{
        .script = "CREATE TABLE wp06_complete_directory_sync (body TEXT);\n",
    };
    try std.testing.expectError(
        error.DirectorySyncFailed,
        store.startupWrite(.{ .context = &context, .run = runStartupScript }),
    );
    try std.testing.expectEqual(@as(usize, 1), context.calls);
    try std.testing.expectEqual(@as(usize, 1), persistence.testing.checkpointCount(&store));
    persistence.testing.setFaults(&store, .{});
    const receipt = try store.completeDurability();
    try std.testing.expectEqual(persistence.State.directory_synchronized, receipt.durability);
    try std.testing.expectEqual(@as(usize, 1), context.calls);
    try std.testing.expectEqual(@as(usize, 1), persistence.testing.checkpointCount(&store));
    try std.testing.expectEqual(persistence.State.ready, store.state());
    try std.testing.expectEqual(@as(?persistence.Diagnostic, null), store.lastDiagnostic());
}

test "refused writes cannot disable eligible persistence-only completion" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(allocator, &tmp, "complete-after-refusal");
    defer allocator.free(path);
    var store = try persistence.testing.openWithFaults(
        allocator,
        std.testing.io,
        path,
        .{ .checkpoint = true },
    );
    defer store.shutdown() catch {};

    var context = ScriptContext{
        .script = "CREATE TABLE wp06_complete_after_refusal (body TEXT);\n",
    };
    try std.testing.expectError(
        error.CheckpointFailed,
        store.startupWrite(.{ .context = &context, .run = runStartupScript }),
    );
    try std.testing.expectEqual(@as(usize, 1), context.calls);
    persistence.testing.setFaults(&store, .{});

    var unused: void = {};
    try std.testing.expectError(
        error.StoreQuarantined,
        store.mutate(.{ .context = &unused, .run = noOpWrite }),
    );
    try std.testing.expectError(
        error.StoreQuarantined,
        store.startupWrite(.{ .context = &context, .run = runStartupScript }),
    );
    try std.testing.expectEqual(persistence.State.quarantined, store.state());
    try std.testing.expectEqual(persistence.DiagnosticCategory.checkpoint_failure, store.lastDiagnostic().?.category);

    const receipt = try store.completeDurability();
    try std.testing.expectEqual(persistence.State.directory_synchronized, receipt.durability);
    try std.testing.expectEqual(@as(usize, 1), context.calls);
    try std.testing.expectEqual(persistence.State.ready, store.state());
    try std.testing.expectEqual(@as(?persistence.Diagnostic, null), store.lastDiagnostic());
}

fn noOpWrite(_: *anyopaque, _: persistence.Executor) !void {}

fn failWrite(_: *anyopaque, _: persistence.Executor) !void {
    return error.ExpectedCallbackFailure;
}

test "only post-commit durability stages are eligible for completion" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var unused: void = {};

    const ready_path = try databasePath(allocator, &tmp, "completion-ready");
    defer allocator.free(ready_path);
    var ready_store = try persistence.Store.open(allocator, std.testing.io, ready_path);
    defer ready_store.shutdown() catch {};
    try std.testing.expectError(error.DurabilityCompletionUnavailable, ready_store.completeDurability());
    try std.testing.expectEqual(persistence.State.ready, ready_store.state());

    const callback_path = try databasePath(allocator, &tmp, "completion-callback");
    defer allocator.free(callback_path);
    var callback_store = try persistence.Store.open(allocator, std.testing.io, callback_path);
    defer callback_store.shutdown() catch {};
    try std.testing.expectError(
        error.CallbackFailed,
        callback_store.mutate(.{ .context = &unused, .run = failWrite }),
    );
    try std.testing.expectError(error.DurabilityCompletionUnavailable, callback_store.completeDurability());
    try std.testing.expectEqual(persistence.DiagnosticCategory.callback_failure, callback_store.lastDiagnostic().?.category);

    const rollback_path = try databasePath(allocator, &tmp, "completion-rollback");
    defer allocator.free(rollback_path);
    var rollback_store = try persistence.testing.openWithFaults(
        allocator,
        std.testing.io,
        rollback_path,
        .{ .rollback = true },
    );
    defer rollback_store.shutdown() catch {};
    try std.testing.expectError(
        error.RollbackFailed,
        rollback_store.mutate(.{ .context = &unused, .run = failWrite }),
    );
    try std.testing.expectError(error.DurabilityCompletionUnavailable, rollback_store.completeDurability());
    try std.testing.expectEqual(persistence.DiagnosticCategory.rollback_failure, rollback_store.lastDiagnostic().?.category);

    const commit_path = try databasePath(allocator, &tmp, "completion-commit");
    defer allocator.free(commit_path);
    var commit_store = try persistence.testing.openWithFaults(
        allocator,
        std.testing.io,
        commit_path,
        .{ .commit = true },
    );
    defer commit_store.shutdown() catch {};
    try std.testing.expectError(
        error.CommitFailed,
        commit_store.mutate(.{ .context = &unused, .run = noOpWrite }),
    );
    try std.testing.expectError(error.DurabilityCompletionUnavailable, commit_store.completeDurability());
    try std.testing.expectEqual(persistence.DiagnosticCategory.commit_failure, commit_store.lastDiagnostic().?.category);
}

test "public facade exposes no adapter storage or unrestricted runtime SQL capability" {
    try std.testing.expect(@typeInfo(persistence.Executor) == .@"enum");
    try std.testing.expect(@typeInfo(persistence.StartupExecutor) == .@"enum");
    try std.testing.expect(@typeInfo(persistence.RowView) == .@"opaque");
    try std.testing.expect(!@hasDecl(persistence.Executor, "executeScript"));
    try std.testing.expect(@hasDecl(persistence.StartupExecutor, "executeScript"));
    try std.testing.expect(@hasDecl(persistence.StartupExecutor, "execute"));
    try std.testing.expect(@hasDecl(persistence.StartupExecutor, "executeBound"));
    try std.testing.expect(@hasDecl(persistence.StartupExecutor, "query"));
    try std.testing.expect(!@hasDecl(persistence.Executor, "adapter"));
    try std.testing.expect(!@hasDecl(persistence.StartupExecutor, "adapter"));
    try std.testing.expect(!@hasDecl(persistence.RowView, "adapter"));
}

const EscalationContext = struct {
    denied: bool = false,
};

fn attemptStartupEscalation(raw_context: *anyopaque, executor: persistence.Executor) !void {
    const context: *EscalationContext = @ptrCast(@alignCast(raw_context));
    const forged: persistence.StartupExecutor = @enumFromInt(@intFromEnum(executor));
    if (forged.executeScript("CREATE TABLE wp06_escalation_must_not_exist (body TEXT);")) |_| {
        return error.UnexpectedCapabilityEscalation;
    } else |err| switch (err) {
        error.CapabilityDenied => context.denied = true,
        else => return err,
    }
}

test "normal executor cannot be cast into the startup runtime-script capability" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(allocator, &tmp, "capability-escalation");
    defer allocator.free(path);
    var store = try persistence.Store.open(allocator, std.testing.io, path);
    defer store.shutdown() catch {};

    var context = EscalationContext{};
    _ = try store.mutate(.{ .context = &context, .run = attemptStartupEscalation });
    try std.testing.expect(context.denied);
    try std.testing.expectError(
        error.QueryFailed,
        persistence.testing.rowCount(&store, "SELECT body FROM wp06_escalation_must_not_exist;"),
    );
}

const RetainedContext = struct {
    executor: ?persistence.Executor = null,
    barrier: *persistence.testing.ExecutorCallBarrier,
    helper: ?std.Thread = null,
    helper_result: ?anyerror = null,
};

fn exerciseAdmittedExecutor(context: *RetainedContext, executor: persistence.Executor) void {
    _ = executor.execute("CREATE TABLE wp06_admitted_before_close (body TEXT);") catch |err| {
        context.helper_result = err;
    };
}

fn retainAndAdmitExecutor(raw_context: *anyopaque, executor: persistence.Executor) !void {
    const context: *RetainedContext = @ptrCast(@alignCast(raw_context));
    context.executor = executor;
    context.helper = try std.Thread.spawn(.{}, exerciseAdmittedExecutor, .{ context, executor });
    const deadline = std.Io.Clock.Timestamp.fromNow(std.testing.io, .{
        .raw = .fromSeconds(1),
        .clock = .awake,
    });
    const pause = std.Io.Clock.Duration{
        .raw = .fromMilliseconds(1),
        .clock = .awake,
    };
    while (!context.barrier.hasAdmitted()) {
        if (std.Io.Clock.Timestamp.now(std.testing.io, .awake).compare(.gte, deadline)) {
            return error.TestTimeout;
        }
        try pause.sleep(std.testing.io);
    }
}

const RetainedMutation = struct {
    store: *persistence.Store,
    context: *RetainedContext,
    result: ?anyerror = null,

    fn run(self: *RetainedMutation) void {
        _ = self.store.mutate(.{ .context = self.context, .run = retainAndAdmitExecutor }) catch |err| {
            self.result = err;
        };
    }
};

fn waitForExecutorClosing(barrier: *persistence.testing.ExecutorCallBarrier) !void {
    const deadline = std.Io.Clock.Timestamp.fromNow(std.testing.io, .{
        .raw = .fromSeconds(1),
        .clock = .awake,
    });
    const pause = std.Io.Clock.Duration{
        .raw = .fromMilliseconds(1),
        .clock = .awake,
    };
    while (!barrier.hasClosing()) {
        if (std.Io.Clock.Timestamp.now(std.testing.io, .awake).compare(.gte, deadline)) {
            return error.TestTimeout;
        }
        try pause.sleep(std.testing.io);
    }
}

test "executor expiry closes admission drains admitted calls and survives retained use" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(allocator, &tmp, "capability-expiry");
    defer allocator.free(path);
    var barrier = persistence.testing.ExecutorCallBarrier{};
    var store = try persistence.testing.openWithFaults(
        allocator,
        std.testing.io,
        path,
        .{ .executor_call_barrier = &barrier },
    );
    defer store.shutdown() catch {};

    var context = RetainedContext{ .barrier = &barrier };
    var mutation = RetainedMutation{ .store = &store, .context = &context };
    const mutation_thread = try std.Thread.spawn(.{}, RetainedMutation.run, .{&mutation});
    var mutation_joined = false;
    var helper_joined = false;
    defer {
        barrier.allow();
        if (!mutation_joined) mutation_thread.join();
        if (!helper_joined) {
            if (context.helper) |helper| helper.join();
        }
    }
    try waitForExecutorClosing(&barrier);
    try std.testing.expectError(
        error.CapabilityDenied,
        context.executor.?.execute("CREATE TABLE wp06_expired_must_not_exist (body TEXT);"),
    );

    barrier.allow();
    context.helper.?.join();
    helper_joined = true;
    mutation_thread.join();
    mutation_joined = true;
    try std.testing.expectEqual(@as(?anyerror, null), context.helper_result);
    try std.testing.expectEqual(@as(?anyerror, null), mutation.result);
    try std.testing.expectEqual(
        @as(usize, 0),
        try persistence.testing.rowCount(&store, "SELECT body FROM wp06_admitted_before_close;"),
    );
    try std.testing.expectError(
        error.CapabilityDenied,
        context.executor.?.execute("CREATE TABLE wp06_expired_after_receipt (body TEXT);"),
    );
    try std.testing.expectError(
        error.QueryFailed,
        persistence.testing.rowCount(&store, "SELECT body FROM wp06_expired_must_not_exist;"),
    );
    try std.testing.expectError(
        error.QueryFailed,
        persistence.testing.rowCount(&store, "SELECT body FROM wp06_expired_after_receipt;"),
    );
}
