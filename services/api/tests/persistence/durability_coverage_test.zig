const std = @import("std");
const persistence = @import("persistence");
const RowView = persistence.RowView;

fn path(allocator: std.mem.Allocator, tmp: *std.testing.TmpDir, name: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/{s}.shovel", .{ tmp.sub_path, name });
}

fn probeRowCount(store: *persistence.Store) persistence.StoreError!usize {
    return persistence.testing.rowCount(store, "SELECT body FROM coverage_probe;");
}

fn admittedRowCount(store: *persistence.Store) persistence.StoreError!usize {
    return persistence.testing.rowCount(store, "SELECT body FROM coverage_admitted;");
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

const FreshCoverageContext = struct {
    calls: usize = 0,
    fail: bool = false,
};

fn freshCoverage(raw_context: *anyopaque, executor: persistence.StartupExecutor) !void {
    const context: *FreshCoverageContext = @ptrCast(@alignCast(raw_context));
    context.calls += 1;
    _ = try executor.execute("CREATE TABLE coverage_fresh (body TEXT);");
    if (context.fail) return error.CoverageFreshFailure;
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
    fail_visit: bool = false,
    skip_setup: bool = false,
    run_query: bool = true,
    run_query_bound: bool = true,
    run_error_checks: bool = true,
    insert_value: []const u8 = "coverage",
    normal: ?persistence.Executor = null,
    startup: ?persistence.StartupExecutor = null,
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
    if (context.fail_visit) return error.CoverageVisitorFailure;
    context.visits += 1;
}

fn richNormal(raw_context: *anyopaque, executor: persistence.Executor) !void {
    const context: *RichContext = @ptrCast(@alignCast(raw_context));
    context.normal = executor;
    if (!context.skip_setup) {
        _ = try executor.execute(
            "CREATE TABLE coverage_rich (id INTEGER, score FLOAT, active BOOLEAN, body TEXT, embedding VECTOR(2));",
        );
        _ = try executor.executeBound(
            &.{ "INSERT INTO coverage_rich VALUES (1, 1.5, TRUE, ", ", [0.25, 0.75]);" },
            &.{context.insert_value},
        );
    }
    if (context.run_query) {
        _ = try executor.query(
            "SELECT NULL, id, score, active, body, embedding FROM coverage_rich;",
            .{ .context = context, .visit = visitRich },
        );
    }
    if (context.run_query_bound) {
        _ = try executor.queryBound(
            &.{ "SELECT NULL, id, score, active, body, embedding FROM coverage_rich WHERE body = ", ";" },
            &.{"coverage"},
            .{ .context = context, .visit = visitRich },
        );
    }
    if (!context.run_error_checks) return;
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
    context.startup = executor;
    if (!context.skip_setup) {
        _ = try executor.executeScript(
            "CREATE TABLE coverage_startup_rich (id INTEGER, score FLOAT, active BOOLEAN, body TEXT, embedding VECTOR(2));\n",
        );
        _ = try executor.executeBound(
            &.{ "INSERT INTO coverage_startup_rich VALUES (1, 1.5, TRUE, ", ", [0.25, 0.75]);" },
            &.{context.insert_value},
        );
    }
    if (context.run_query) {
        _ = try executor.query(
            "SELECT NULL, id, score, active, body, embedding FROM coverage_startup_rich;",
            .{ .context = context, .visit = visitRich },
        );
    }
    if (context.run_query_bound) {
        _ = try executor.queryBound(
            &.{ "SELECT NULL, id, score, active, body, embedding FROM coverage_startup_rich WHERE body = ", ";" },
            &.{"coverage"},
            .{ .context = context, .visit = visitRich },
        );
    }
    if (!context.run_error_checks) return;
    _ = executor.executeScript("CREATE TABLE coverage_nul (body TEXT);\x00") catch {};
    _ = executor.executeScript("CREATE TABLE coverage_one (body TEXT); CREATE TABLE coverage_two (body TEXT);") catch {};
    const forged: persistence.Executor = @enumFromInt(@intFromEnum(executor));
    _ = forged.execute("CREATE TABLE coverage_admitted (body TEXT);") catch |err| {
        if (err == error.CapabilityDenied) context.denied = true;
    };
}

fn expectRichNormalDenied(executor: persistence.Executor, context: *RichContext) !void {
    try std.testing.expectError(error.CapabilityDenied, executor.execute("CREATE TABLE coverage_probe (body TEXT);"));
    try std.testing.expectError(error.CapabilityDenied, executor.execute("SELECT body FROM coverage_probe;"));
    try std.testing.expectError(error.CapabilityDenied, executor.execute("SELECT FROM invalid_coverage_statement;"));
    try std.testing.expectError(
        error.CapabilityDenied,
        executor.execute("CREATE TABLE coverage_rich (id INTEGER, score FLOAT, active BOOLEAN, body TEXT, embedding VECTOR(2));"),
    );
    try std.testing.expectError(error.CapabilityDenied, executor.execute("SELECT FROM sql-sentinel-DO-NOT-LEAK;"));
    try std.testing.expectError(error.CapabilityDenied, executor.execute("SELECT body FROM coverage_missing;"));
    try std.testing.expectError(error.CapabilityDenied, executor.execute("CREATE TABLE coverage_admitted (body TEXT);"));
    try std.testing.expectError(
        error.CapabilityDenied,
        executor.executeText("INSERT INTO coverage_probe VALUES (", "coverage", ");"),
    );
    try std.testing.expectError(
        error.CapabilityDenied,
        executor.executeBound(
            &.{ "INSERT INTO coverage_rich VALUES (1, 1.5, TRUE, ", ", [0.25, 0.75]);" },
            &.{"coverage"},
        ),
    );
    try std.testing.expectError(
        error.CapabilityDenied,
        executor.executeBound(&.{"SELECT id FROM coverage_rich WHERE body = "}, &.{"coverage"}),
    );
    try std.testing.expectError(
        error.CapabilityDenied,
        executor.executeBound(&.{ "SELECT id FROM coverage_rich WHERE body = ", ";" }, &.{"nul\x00value"}),
    );
    try std.testing.expectError(
        error.CapabilityDenied,
        executor.query(
            "SELECT NULL, id, score, active, body, embedding FROM coverage_rich;",
            .{ .context = context, .visit = visitRich },
        ),
    );
    try std.testing.expectError(
        error.CapabilityDenied,
        executor.query(
            "CREATE TABLE coverage_rows_required (body TEXT);",
            .{ .context = context, .visit = visitRich },
        ),
    );
    try std.testing.expectError(
        error.CapabilityDenied,
        executor.queryBound(
            &.{ "SELECT NULL, id, score, active, body, embedding FROM coverage_rich WHERE body = ", ";" },
            &.{"coverage"},
            .{ .context = context, .visit = visitRich },
        ),
    );
}

fn expectRichStartupDenied(executor: persistence.StartupExecutor, context: *RichContext) !void {
    try std.testing.expectError(error.CapabilityDenied, executor.execute("CREATE TABLE coverage_probe (body TEXT);"));
    try std.testing.expectError(
        error.CapabilityDenied,
        executor.executeText("INSERT INTO coverage_probe VALUES (", "coverage", ");"),
    );
    try std.testing.expectError(
        error.CapabilityDenied,
        executor.executeBound(
            &.{ "INSERT INTO coverage_startup_rich VALUES (1, 1.5, TRUE, ", ", [0.25, 0.75]);" },
            &.{"coverage"},
        ),
    );
    try std.testing.expectError(
        error.CapabilityDenied,
        executor.query(
            "SELECT NULL, id, score, active, body, embedding FROM coverage_startup_rich;",
            .{ .context = context, .visit = visitRich },
        ),
    );
    try std.testing.expectError(
        error.CapabilityDenied,
        executor.queryBound(
            &.{ "SELECT NULL, id, score, active, body, embedding FROM coverage_startup_rich WHERE body = ", ";" },
            &.{"coverage"},
            .{ .context = context, .visit = visitRich },
        ),
    );
}

const RichAlternate = enum {
    repeat_create,
    select_created_missing,
    insert_nul,
    select_clean,
    query_after_drop,
    query_bound_after_drop,
};

const RichAlternateContext = struct {
    operation: RichAlternate,
    rich: *RichContext,
};

fn richNormalAlternate(raw_context: *anyopaque, executor: persistence.Executor) !void {
    const context: *RichAlternateContext = @ptrCast(@alignCast(raw_context));
    switch (context.operation) {
        .repeat_create => _ = try executor.execute(
            "CREATE TABLE coverage_rich (id INTEGER, score FLOAT, active BOOLEAN, body TEXT, embedding VECTOR(2));",
        ),
        .select_created_missing => _ = try executor.execute("SELECT body FROM coverage_missing;"),
        .insert_nul => _ = try executor.executeBound(
            &.{ "INSERT INTO coverage_rich VALUES (1, 1.5, TRUE, ", ", [0.25, 0.75]);" },
            &.{"nul\x00value"},
        ),
        .select_clean => _ = try executor.executeBound(
            &.{ "SELECT id FROM coverage_rich WHERE body = ", ";" },
            &.{"coverage"},
        ),
        .query_after_drop => _ = try executor.query(
            "SELECT NULL, id, score, active, body, embedding FROM coverage_rich;",
            .{ .context = context.rich, .visit = visitRich },
        ),
        .query_bound_after_drop => _ = try executor.queryBound(
            &.{ "SELECT NULL, id, score, active, body, embedding FROM coverage_rich WHERE body = ", ";" },
            &.{"coverage"},
            .{ .context = context.rich, .visit = visitRich },
        ),
    }
}

const StartupAlternate = enum {
    insert_nul,
    query_after_drop,
    query_bound_after_drop,
};

const StartupAlternateContext = struct {
    operation: StartupAlternate,
    rich: *RichContext,
};

fn richStartupAlternate(raw_context: *anyopaque, executor: persistence.StartupExecutor) !void {
    const context: *StartupAlternateContext = @ptrCast(@alignCast(raw_context));
    switch (context.operation) {
        .insert_nul => _ = try executor.executeBound(
            &.{ "INSERT INTO coverage_startup_rich VALUES (1, 1.5, TRUE, ", ", [0.25, 0.75]);" },
            &.{"nul\x00value"},
        ),
        .query_after_drop => _ = try executor.query(
            "SELECT NULL, id, score, active, body, embedding FROM coverage_startup_rich;",
            .{ .context = context.rich, .visit = visitRich },
        ),
        .query_bound_after_drop => _ = try executor.queryBound(
            &.{ "SELECT NULL, id, score, active, body, embedding FROM coverage_startup_rich WHERE body = ", ";" },
            &.{"coverage"},
            .{ .context = context.rich, .visit = visitRich },
        ),
    }
}

const RuntimeScriptContext = struct {
    script: []const u8,
};

fn executeRuntimeScript(raw_context: *anyopaque, executor: persistence.StartupExecutor) !void {
    const context: *RuntimeScriptContext = @ptrCast(@alignCast(raw_context));
    _ = try executor.executeScript(context.script);
}

fn noOp(_: *anyopaque, _: persistence.Executor) !void {}

fn startupNoOp(_: *anyopaque, _: persistence.StartupExecutor) !void {}

const CountContext = struct {
    calls: usize = 0,
};

fn countNoOp(raw_context: *anyopaque, _: persistence.Executor) !void {
    const context: *CountContext = @ptrCast(@alignCast(raw_context));
    context.calls += 1;
}

const ExecutorOperation = enum {
    execute,
    execute_text,
    execute_bound,
    query,
    query_bound,
};

const SpecializationContext = struct {
    operation: ExecutorOperation,
    expect_missing_object: bool,
    visits: usize = 0,
};

fn visitSpecialization(raw_context: *anyopaque, row: *const RowView) !void {
    const context: *SpecializationContext = @ptrCast(@alignCast(raw_context));
    try std.testing.expectEqual(@as(usize, 1), row.len());
    _ = try row.value(0);
    context.visits += 1;
}

fn settleStatement(context: *SpecializationContext, result: persistence.StoreError!persistence.StatementResult) !void {
    if (context.expect_missing_object) {
        if (result) |_| {
            return error.ExpectedMissingObject;
        } else |err| {
            try std.testing.expectEqual(error.StatementObjectFailed, err);
            return error.CoveragePlannedRollback;
        }
    }
    _ = try result;
}

fn settleQuery(context: *SpecializationContext, result: anyerror!usize) !void {
    if (context.expect_missing_object) {
        if (result) |_| {
            return error.ExpectedMissingObject;
        } else |err| {
            try std.testing.expectEqual(error.StatementObjectFailed, err);
            return error.CoveragePlannedRollback;
        }
    }
    _ = try result;
}

fn exerciseNormalSpecialization(raw_context: *anyopaque, executor: persistence.Executor) !void {
    const context: *SpecializationContext = @ptrCast(@alignCast(raw_context));
    switch (context.operation) {
        .execute => try settleStatement(
            context,
            executor.execute("SELECT body FROM coverage_specialization;"),
        ),
        .execute_text => try settleStatement(
            context,
            executor.executeText(
                "INSERT INTO coverage_specialization VALUES (",
                "normal-text",
                ");",
            ),
        ),
        .execute_bound => try settleStatement(
            context,
            executor.executeBound(
                &.{ "INSERT INTO coverage_specialization VALUES (", ");" },
                &.{"normal-bound"},
            ),
        ),
        .query => try settleQuery(
            context,
            executor.query(
                "SELECT body FROM coverage_specialization;",
                .{ .context = context, .visit = visitSpecialization },
            ),
        ),
        .query_bound => try settleQuery(
            context,
            executor.queryBound(
                &.{ "SELECT body FROM coverage_specialization WHERE body = ", ";" },
                &.{"normal-text"},
                .{ .context = context, .visit = visitSpecialization },
            ),
        ),
    }
}

fn createNormalSpecializationSchema(_: *anyopaque, executor: persistence.Executor) !void {
    _ = try executor.execute("CREATE TABLE coverage_specialization (body TEXT);");
}

const RetainedNormalSurface = struct {
    executor: ?persistence.Executor = null,
};

fn retainNormalSurface(raw_context: *anyopaque, executor: persistence.Executor) !void {
    const context: *RetainedNormalSurface = @ptrCast(@alignCast(raw_context));
    context.executor = executor;
}

fn exerciseStartupSpecialization(raw_context: *anyopaque, executor: persistence.StartupExecutor) !void {
    const context: *SpecializationContext = @ptrCast(@alignCast(raw_context));
    switch (context.operation) {
        .execute => try settleStatement(
            context,
            executor.execute("SELECT body FROM coverage_startup_specialization;"),
        ),
        .execute_text => try settleStatement(
            context,
            executor.executeText(
                "INSERT INTO coverage_startup_specialization VALUES (",
                "startup-text",
                ");",
            ),
        ),
        .execute_bound => try settleStatement(
            context,
            executor.executeBound(
                &.{ "INSERT INTO coverage_startup_specialization VALUES (", ");" },
                &.{"startup-bound"},
            ),
        ),
        .query => try settleQuery(
            context,
            executor.query(
                "SELECT body FROM coverage_startup_specialization;",
                .{ .context = context, .visit = visitSpecialization },
            ),
        ),
        .query_bound => try settleQuery(
            context,
            executor.queryBound(
                &.{ "SELECT body FROM coverage_startup_specialization WHERE body = ", ";" },
                &.{"startup-text"},
                .{ .context = context, .visit = visitSpecialization },
            ),
        ),
    }
}

fn createStartupSpecializationSchema(_: *anyopaque, executor: persistence.StartupExecutor) !void {
    _ = try executor.executeScript("CREATE TABLE coverage_startup_specialization (body TEXT);\n");
}

const RetainedStartupSurface = struct {
    executor: ?persistence.StartupExecutor = null,
};

fn retainStartupSurface(raw_context: *anyopaque, executor: persistence.StartupExecutor) !void {
    const context: *RetainedStartupSurface = @ptrCast(@alignCast(raw_context));
    context.executor = executor;
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

fn repeatAdmittedStatement(_: *anyopaque, executor: persistence.Executor) !void {
    _ = try executor.execute("CREATE TABLE coverage_admitted (body TEXT);");
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
    try std.testing.expectError(error.DurabilityCompletionUnavailable, store.completeDurability());
    try std.testing.expectError(
        error.QueryFailed,
        probeRowCount(&store),
    );
    var unused: void = {};
    const created = try store.mutate(.{ .context = &unused, .run = success });
    try std.testing.expectEqual(persistence.State.directory_synchronized, created.durability);
    _ = try store.startupWrite(.{ .context = &unused, .run = startupInsert });
    _ = try store.mutate(.{ .context = &unused, .run = selectRows });
    try std.testing.expectEqual(@as(usize, 1), try probeRowCount(&store));
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
    try std.testing.expectError(error.StoreClosed, probeRowCount(&store));
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

    const bare_path = "coverage-wp06-bare-relative.shovel";
    const bare_lock_path = bare_path ++ ".lock";
    std.Io.Dir.deleteFile(.cwd(), std.testing.io, bare_path) catch {};
    std.Io.Dir.deleteFile(.cwd(), std.testing.io, bare_lock_path) catch {};
    defer std.Io.Dir.deleteFile(.cwd(), std.testing.io, bare_path) catch {};
    defer std.Io.Dir.deleteFile(.cwd(), std.testing.io, bare_lock_path) catch {};
    var bare_store = try persistence.Store.open(allocator, std.testing.io, bare_path);
    try bare_store.shutdown();
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

    const registration_rollback_path = try path(allocator, &tmp, "executor-registration-rollback");
    defer allocator.free(registration_rollback_path);
    var registration_rollback_store = try persistence.testing.openWithFaults(
        allocator,
        std.testing.io,
        registration_rollback_path,
        .{ .executor_registration = true, .rollback = true },
    );
    defer registration_rollback_store.shutdown() catch {};
    try std.testing.expectError(
        error.RollbackFailed,
        registration_rollback_store.mutate(.{ .context = &unused, .run = success }),
    );

    const operation_rollback_path = try path(allocator, &tmp, "operation-callback-rollback");
    defer allocator.free(operation_rollback_path);
    var operation_rollback_store = try persistence.testing.openWithFaults(
        allocator,
        std.testing.io,
        operation_rollback_path,
        .{ .rollback = true },
    );
    defer operation_rollback_store.shutdown() catch {};
    try std.testing.expectError(
        error.RollbackFailed,
        operation_rollback_store.mutate(.{ .context = &unused, .run = failure }),
    );
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

    const rename_source = try path(allocator, &tmp, "coverage-rename-source");
    defer allocator.free(rename_source);
    const rename_target = try path(allocator, &tmp, "coverage-rename-target");
    defer allocator.free(rename_target);
    var renamed_store = try persistence.Store.open(allocator, std.testing.io, rename_source);
    var unused: void = {};
    _ = try renamed_store.mutate(.{ .context = &unused, .run = success });
    try std.Io.Dir.rename(.cwd(), rename_source, .cwd(), rename_target, std.testing.io);
    try std.testing.expectError(
        error.LeaseConflict,
        persistence.Store.open(allocator, std.testing.io, rename_target),
    );
    try renamed_store.shutdown();
    var renamed_reopen = try persistence.Store.open(allocator, std.testing.io, rename_target);
    try renamed_reopen.shutdown();
}

test "dynamic registries reclaim non-head stores and executor scopes" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const first_path = try path(allocator, &tmp, "coverage-registry-first");
    defer allocator.free(first_path);
    const second_path = try path(allocator, &tmp, "coverage-registry-second");
    defer allocator.free(second_path);
    var first = try persistence.Store.open(allocator, std.testing.io, first_path);
    var second = try persistence.Store.open(allocator, std.testing.io, second_path);
    try std.testing.expectEqual(persistence.State.ready, first.state());
    try std.testing.expectEqual(@as(?persistence.Diagnostic, null), first.lastDiagnostic());

    var first_context = ClosingContext{};
    var second_context = ClosingContext{};
    const first_mutation = try std.Thread.spawn(.{}, mutationThread, .{ &first, &first_context });
    try waitForAtomic(&first_context.entered);
    const second_mutation = try std.Thread.spawn(.{}, mutationThread, .{ &second, &second_context });
    try waitForAtomic(&second_context.entered);
    first_context.release.store(true, .release);
    first_mutation.join();
    second_context.release.store(true, .release);
    second_mutation.join();
    try std.testing.expectEqual(@as(?anyerror, null), first_context.result);
    try std.testing.expectEqual(@as(?anyerror, null), second_context.result);

    try first.shutdown();
    try first.shutdown();
    try std.testing.expectEqual(persistence.State.closed, first.state());
    try std.testing.expectEqual(@as(?persistence.Diagnostic, null), first.lastDiagnostic());
    try std.testing.expectError(error.StoreClosed, first.completeDurability());
    try std.testing.expectEqual(persistence.State.ready, second.state());
    try second.shutdown();
}

test "concurrent successful shutdown waiters share reclamation and archived outcome" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try path(allocator, &tmp, "coverage-successful-shutdown-waiters");
    defer allocator.free(database_path);
    var shutdown_barrier = persistence.testing.ShutdownCallBarrier{};
    var store = try persistence.testing.openWithFaults(
        allocator,
        std.testing.io,
        database_path,
        .{ .shutdown_call_barrier = &shutdown_barrier },
    );
    var context = ClosingContext{};
    const mutation = try std.Thread.spawn(.{}, mutationThread, .{ &store, &context });
    try waitForAtomic(&context.entered);

    var leader = ShutdownAttempt{ .store = &store };
    const leader_thread = try std.Thread.spawn(.{}, ShutdownAttempt.run, .{&leader});
    try shutdown_barrier.waitForCallers(1, std.testing.io);
    var waiter = ShutdownAttempt{ .store = &store };
    const waiter_thread = try std.Thread.spawn(.{}, ShutdownAttempt.run, .{&waiter});
    try shutdown_barrier.waitForCallers(2, std.testing.io);
    try std.testing.expect(!leader.done.load(.acquire));
    try std.testing.expect(!waiter.done.load(.acquire));

    context.release.store(true, .release);
    mutation.join();
    leader_thread.join();
    waiter_thread.join();
    try std.testing.expectEqual(@as(?anyerror, null), context.result);
    try std.testing.expectEqual(@as(?anyerror, null), leader.result);
    try std.testing.expectEqual(@as(?anyerror, null), waiter.result);
    try std.testing.expect(shutdown_barrier.hasReclaimed());
    try store.shutdown();
    try std.testing.expectEqual(persistence.State.closed, store.state());
    try std.testing.expectEqual(@as(?persistence.Diagnostic, null), store.lastDiagnostic());
}

test "shutdown barrier reports a bounded deadline when no caller arrives" {
    var barrier = persistence.testing.ShutdownCallBarrier{};
    try std.testing.expectError(error.TestTimeout, barrier.waitForCallers(1, std.testing.io));
}

test "executor specializations cover failure success and expired admission paths" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const normal_path = try path(allocator, &tmp, "coverage-specializations");
    defer allocator.free(normal_path);
    var normal_store = try persistence.Store.open(allocator, std.testing.io, normal_path);
    defer normal_store.shutdown() catch {};

    const operations = [_]ExecutorOperation{ .execute, .execute_text, .execute_bound, .query, .query_bound };
    for (operations) |operation| {
        var context = SpecializationContext{
            .operation = operation,
            .expect_missing_object = true,
        };
        try std.testing.expectError(
            error.CallbackFailed,
            normal_store.mutate(.{ .context = &context, .run = exerciseNormalSpecialization }),
        );
    }
    var unused: void = {};
    _ = try normal_store.mutate(.{ .context = &unused, .run = createNormalSpecializationSchema });
    try std.testing.expectError(
        error.CallbackFailed,
        normal_store.mutate(.{ .context = &unused, .run = createNormalSpecializationSchema }),
    );
    for (operations) |operation| {
        var context = SpecializationContext{
            .operation = operation,
            .expect_missing_object = false,
        };
        _ = try normal_store.mutate(.{ .context = &context, .run = exerciseNormalSpecialization });
    }
    var retained_normal = RetainedNormalSurface{};
    _ = try normal_store.mutate(.{ .context = &retained_normal, .run = retainNormalSurface });
    const normal = retained_normal.executor.?;
    for (operations) |operation| {
        var context = SpecializationContext{
            .operation = operation,
            .expect_missing_object = false,
        };
        try std.testing.expectError(
            error.CapabilityDenied,
            exerciseNormalSpecialization(&context, normal),
        );
    }

    const startup_path = try path(allocator, &tmp, "coverage-startup-specializations");
    defer allocator.free(startup_path);
    var startup_store = try persistence.Store.open(allocator, std.testing.io, startup_path);
    defer startup_store.shutdown() catch {};
    for (operations) |operation| {
        var context = SpecializationContext{
            .operation = operation,
            .expect_missing_object = true,
        };
        try std.testing.expectError(
            error.StartupWriteFailed,
            startup_store.startupWrite(.{ .context = &context, .run = exerciseStartupSpecialization }),
        );
    }
    _ = try startup_store.startupWrite(.{ .context = &unused, .run = createStartupSpecializationSchema });
    try std.testing.expectError(
        error.StartupWriteFailed,
        startup_store.startupWrite(.{ .context = &unused, .run = createStartupSpecializationSchema }),
    );
    for (operations) |operation| {
        var context = SpecializationContext{
            .operation = operation,
            .expect_missing_object = false,
        };
        _ = try startup_store.startupWrite(.{ .context = &context, .run = exerciseStartupSpecialization });
    }
    var retained_startup = RetainedStartupSurface{};
    _ = try startup_store.startupWrite(.{ .context = &retained_startup, .run = retainStartupSurface });
    const startup = retained_startup.executor.?;
    for (operations) |operation| {
        var context = SpecializationContext{
            .operation = operation,
            .expect_missing_object = false,
        };
        try std.testing.expectError(
            error.CapabilityDenied,
            exerciseStartupSpecialization(&context, startup),
        );
    }
    try std.testing.expectError(
        error.CapabilityDenied,
        startup.executeScript("CREATE TABLE coverage_expired_startup (body TEXT);"),
    );
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

test "shutdown failure preserves the earlier checkpoint diagnostic" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try path(allocator, &tmp, "coverage-causal-shutdown");
    defer allocator.free(database_path);
    var store = try persistence.testing.openWithFaults(
        allocator,
        std.testing.io,
        database_path,
        .{ .checkpoint = true, .shutdown = true },
    );
    var unused: void = {};
    try std.testing.expectError(
        error.CheckpointFailed,
        store.mutate(.{ .context = &unused, .run = noOp }),
    );
    const checkpoint_diagnostic = store.lastDiagnostic().?;
    try std.testing.expectEqual(persistence.DiagnosticCategory.checkpoint_failure, checkpoint_diagnostic.category);
    try std.testing.expectError(error.ShutdownFailed, store.shutdown());
    const terminal_diagnostic = store.lastDiagnostic().?;
    try std.testing.expectEqual(checkpoint_diagnostic, terminal_diagnostic);
}

test "zero and evicted store capabilities remain closed without registry state" {
    var unused: void = {};
    var zero: persistence.Store = @enumFromInt(0);
    try std.testing.expectEqual(persistence.State.closed, zero.state());
    try std.testing.expectEqual(@as(?persistence.Diagnostic, null), zero.lastDiagnostic());
    try std.testing.expectError(error.StoreClosed, zero.mutate(.{ .context = &unused, .run = noOp }));
    try std.testing.expectError(
        error.StoreClosed,
        zero.startupWrite(.{ .context = &unused, .run = startupNoOp }),
    );
    try std.testing.expectError(error.StoreClosed, zero.completeDurability());
    try zero.shutdown();

    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var first_closed: ?persistence.Store = null;
    for (0..257) |index| {
        const name = try std.fmt.allocPrint(allocator, "coverage-eviction-{d}", .{index});
        defer allocator.free(name);
        const database_path = try path(allocator, &tmp, name);
        defer allocator.free(database_path);
        var store = try persistence.Store.open(allocator, std.testing.io, database_path);
        if (index == 0) first_closed = store;
        try store.shutdown();
    }

    var evicted = first_closed.?;
    try std.testing.expectEqual(persistence.State.closed, evicted.state());
    try std.testing.expectEqual(@as(?persistence.Diagnostic, null), evicted.lastDiagnostic());
    try std.testing.expectError(error.StoreClosed, evicted.mutate(.{ .context = &unused, .run = noOp }));
    try evicted.shutdown();
}

test "allocator failures reclaim partial stores and executor registrations" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var open_failures: usize = 0;
    var open_successes: usize = 0;
    var mutation_oom: usize = 0;
    var unused: void = {};

    for (0..256) |failure_index| {
        const name = try std.fmt.allocPrint(allocator, "coverage-allocation-{d}", .{failure_index});
        defer allocator.free(name);
        const database_path = try path(allocator, &tmp, name);
        defer allocator.free(database_path);
        var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = failure_index });
        if (persistence.Store.open(failing.allocator(), std.testing.io, database_path)) |opened| {
            open_successes += 1;
            var store = opened;
            _ = store.mutate(.{ .context = &unused, .run = noOp }) catch |err| {
                if (err == error.OutOfMemory) mutation_oom += 1;
            };
            store.shutdown() catch {};
        } else |_| {
            open_failures += 1;
        }
    }

    try std.testing.expect(open_failures > 0);
    try std.testing.expect(open_successes > 0);
    try std.testing.expect(mutation_oom > 0);

    const existing_path = try path(allocator, &tmp, "coverage-existing-allocation");
    defer allocator.free(existing_path);
    var created = try persistence.Store.open(allocator, std.testing.io, existing_path);
    try created.shutdown();
    for (0..16) |failure_index| {
        var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = failure_index });
        if (persistence.Store.open(failing.allocator(), std.testing.io, existing_path)) |opened| {
            var store = opened;
            store.shutdown() catch {};
        } else |_| {}
    }
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
    try expectRichNormalDenied(normal_context.normal.?, &normal_context);
    try expectRichNormalDenied(@enumFromInt(0), &normal_context);
    try std.testing.expectError(
        error.CallbackFailed,
        store.mutate(.{ .context = &normal_context, .run = richNormal }),
    );

    var normal_alternate = RichAlternateContext{ .operation = .repeat_create, .rich = &normal_context };
    try std.testing.expectError(
        error.CallbackFailed,
        store.mutate(.{ .context = &normal_alternate, .run = richNormalAlternate }),
    );
    var script = RuntimeScriptContext{ .script = "CREATE TABLE coverage_missing (body TEXT);" };
    _ = try store.startupWrite(.{ .context = &script, .run = executeRuntimeScript });
    normal_alternate.operation = .select_created_missing;
    _ = try store.mutate(.{ .context = &normal_alternate, .run = richNormalAlternate });
    normal_alternate.operation = .insert_nul;
    try std.testing.expectError(
        error.CallbackFailed,
        store.mutate(.{ .context = &normal_alternate, .run = richNormalAlternate }),
    );
    normal_alternate.operation = .select_clean;
    _ = try store.mutate(.{ .context = &normal_alternate, .run = richNormalAlternate });

    var startup_context = RichContext{};
    _ = try store.startupWrite(.{ .context = &startup_context, .run = richStartup });
    try std.testing.expect(startup_context.visits >= 2);
    try std.testing.expect(startup_context.denied);
    try expectRichStartupDenied(startup_context.startup.?, &startup_context);
    try expectRichStartupDenied(@enumFromInt(0), &startup_context);

    var startup_alternate = StartupAlternateContext{ .operation = .insert_nul, .rich = &startup_context };
    try std.testing.expectError(
        error.StartupWriteFailed,
        store.startupWrite(.{ .context = &startup_alternate, .run = richStartupAlternate }),
    );

    script.script = "DROP TABLE coverage_rich;";
    _ = try store.startupWrite(.{ .context = &script, .run = executeRuntimeScript });
    script.script = "DROP TABLE coverage_startup_rich;";
    _ = try store.startupWrite(.{ .context = &script, .run = executeRuntimeScript });
    normal_alternate.operation = .query_after_drop;
    try std.testing.expectError(
        error.CallbackFailed,
        store.mutate(.{ .context = &normal_alternate, .run = richNormalAlternate }),
    );
    normal_alternate.operation = .query_bound_after_drop;
    try std.testing.expectError(
        error.CallbackFailed,
        store.mutate(.{ .context = &normal_alternate, .run = richNormalAlternate }),
    );
    startup_alternate.operation = .query_after_drop;
    try std.testing.expectError(
        error.StartupWriteFailed,
        store.startupWrite(.{ .context = &startup_alternate, .run = richStartupAlternate }),
    );
    startup_alternate.operation = .query_bound_after_drop;
    try std.testing.expectError(
        error.StartupWriteFailed,
        store.startupWrite(.{ .context = &startup_alternate, .run = richStartupAlternate }),
    );
}

test "row visitor failures abort normal and startup callbacks through live query callsites" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const normal_path = try path(allocator, &tmp, "coverage-normal-visitor-failure");
    defer allocator.free(normal_path);
    var normal_store = try persistence.Store.open(allocator, std.testing.io, normal_path);
    defer normal_store.shutdown() catch {};
    var normal_context = RichContext{ .fail_visit = true };
    try std.testing.expectError(
        error.CallbackFailed,
        normal_store.mutate(.{ .context = &normal_context, .run = richNormal }),
    );
    normal_context = .{
        .insert_value = "nul\x00value",
        .run_query = false,
        .run_query_bound = false,
        .run_error_checks = false,
    };
    try std.testing.expectError(
        error.CallbackFailed,
        normal_store.mutate(.{ .context = &normal_context, .run = richNormal }),
    );
    var drop_normal = RuntimeScriptContext{ .script = "DROP TABLE coverage_rich;" };
    _ = try normal_store.startupWrite(.{ .context = &drop_normal, .run = executeRuntimeScript });
    normal_context = .{
        .skip_setup = true,
        .run_query_bound = false,
        .run_error_checks = false,
    };
    try std.testing.expectError(
        error.CallbackFailed,
        normal_store.mutate(.{ .context = &normal_context, .run = richNormal }),
    );
    normal_context = .{
        .skip_setup = true,
        .run_query = false,
        .run_error_checks = false,
    };
    try std.testing.expectError(
        error.CallbackFailed,
        normal_store.mutate(.{ .context = &normal_context, .run = richNormal }),
    );

    const startup_path = try path(allocator, &tmp, "coverage-startup-visitor-failure");
    defer allocator.free(startup_path);
    var startup_store = try persistence.Store.open(allocator, std.testing.io, startup_path);
    defer startup_store.shutdown() catch {};
    var startup_context = RichContext{ .fail_visit = true };
    try std.testing.expectError(
        error.StartupWriteFailed,
        startup_store.startupWrite(.{ .context = &startup_context, .run = richStartup }),
    );
    startup_context = .{
        .insert_value = "nul\x00value",
        .run_query = false,
        .run_query_bound = false,
        .run_error_checks = false,
    };
    try std.testing.expectError(
        error.StartupWriteFailed,
        startup_store.startupWrite(.{ .context = &startup_context, .run = richStartup }),
    );
    startup_context = .{
        .skip_setup = true,
        .run_query_bound = false,
        .run_error_checks = false,
    };
    try std.testing.expectError(
        error.StartupWriteFailed,
        startup_store.startupWrite(.{ .context = &startup_context, .run = richStartup }),
    );
    startup_context = .{
        .skip_setup = true,
        .run_query = false,
        .run_error_checks = false,
    };
    try std.testing.expectError(
        error.StartupWriteFailed,
        startup_store.startupWrite(.{ .context = &startup_context, .run = richStartup }),
    );
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

    const identity_path = try path(allocator, &tmp, "coverage-complete-identity");
    defer allocator.free(identity_path);
    var identity_store = try persistence.Store.open(allocator, std.testing.io, identity_path);
    defer identity_store.shutdown() catch {};
    var identity_context = CountContext{};
    persistence.testing.setFaults(&identity_store, .{ .identity_inspection = true });
    try std.testing.expectError(
        error.LeaseAcquireFailed,
        identity_store.mutate(.{ .context = &identity_context, .run = countNoOp }),
    );
    try std.testing.expectEqual(@as(usize, 1), identity_context.calls);
    try std.testing.expectEqual(
        persistence.DiagnosticCategory.lease_acquire_failure,
        identity_store.lastDiagnostic().?.category,
    );
    persistence.testing.setFaults(&identity_store, .{});
    _ = try identity_store.completeDurability();
    try std.testing.expectEqual(@as(usize, 1), identity_context.calls);
    try std.testing.expectEqual(@as(?persistence.Diagnostic, null), identity_store.lastDiagnostic());

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
        context.executor.?.execute("CREATE TABLE coverage_admitted (body TEXT);"),
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
        try admittedRowCount(&store),
    );
    var unused: void = {};
    try std.testing.expectError(
        error.CallbackFailed,
        store.mutate(.{ .context = &unused, .run = repeatAdmittedStatement }),
    );
    var drop_admitted = RuntimeScriptContext{ .script = "DROP TABLE coverage_admitted;" };
    _ = try store.startupWrite(.{ .context = &drop_admitted, .run = executeRuntimeScript });
    try std.testing.expectError(error.QueryFailed, admittedRowCount(&store));
    try std.testing.expectError(
        error.CapabilityDenied,
        context.executor.?.execute("CREATE TABLE coverage_admitted (body TEXT);"),
    );
    try store.shutdown();
    try std.testing.expectError(error.StoreClosed, admittedRowCount(&store));
}

test "executor admission barrier has a bounded unreleased deadline" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try path(allocator, &tmp, "coverage-executor-deadline");
    defer allocator.free(database_path);
    var barrier = persistence.testing.ExecutorCallBarrier{};
    var store = try persistence.testing.openWithFaults(
        allocator,
        std.testing.io,
        database_path,
        .{ .executor_call_barrier = &barrier },
    );
    defer store.shutdown() catch {};
    var unused: void = {};
    _ = try store.mutate(.{ .context = &unused, .run = success });
    try std.testing.expect(barrier.hasAdmitted());
    try std.testing.expect(barrier.hasClosing());
}

test "fresh initialization covers origin denial recovery and durability completion" {
    const allocator = std.testing.allocator;

    var existing_tmp = std.testing.tmpDir(.{});
    defer existing_tmp.cleanup();
    const existing_path = try path(allocator, &existing_tmp, "fresh-existing");
    defer allocator.free(existing_path);
    var creator = try persistence.Store.open(allocator, std.testing.io, existing_path);
    try creator.shutdown();
    var existing = try persistence.Store.open(allocator, std.testing.io, existing_path);
    defer existing.shutdown() catch {};
    var denied_context = FreshCoverageContext{};
    try std.testing.expectError(
        error.NotFresh,
        existing.initializeFresh(.{ .context = &denied_context, .run = freshCoverage }),
    );
    try std.testing.expectEqual(@as(usize, 0), denied_context.calls);
    try std.testing.expectEqual(persistence.DiagnosticCategory.not_fresh, existing.lastDiagnostic().?.category);

    var retry_tmp = std.testing.tmpDir(.{});
    defer retry_tmp.cleanup();
    const retry_path = try path(allocator, &retry_tmp, "fresh-retry");
    defer allocator.free(retry_path);
    var retry_store = try persistence.Store.open(allocator, std.testing.io, retry_path);
    defer retry_store.shutdown() catch {};
    var retry_context = FreshCoverageContext{ .fail = true };
    try std.testing.expectError(
        error.StartupWriteFailed,
        retry_store.initializeFresh(.{ .context = &retry_context, .run = freshCoverage }),
    );
    retry_context.fail = false;
    _ = try retry_store.initializeFresh(.{ .context = &retry_context, .run = freshCoverage });
    try std.testing.expectEqual(@as(usize, 2), retry_context.calls);

    var completion_tmp = std.testing.tmpDir(.{});
    defer completion_tmp.cleanup();
    const completion_path = try path(allocator, &completion_tmp, "fresh-completion");
    defer allocator.free(completion_path);
    var completion_store = try persistence.testing.openWithFaults(
        allocator,
        std.testing.io,
        completion_path,
        .{ .checkpoint = true },
    );
    defer completion_store.shutdown() catch {};
    var completion_context = FreshCoverageContext{};
    try std.testing.expectError(
        error.CheckpointFailed,
        completion_store.initializeFresh(.{ .context = &completion_context, .run = freshCoverage }),
    );
    try std.testing.expectError(
        error.StoreQuarantined,
        completion_store.initializeFresh(.{ .context = &completion_context, .run = freshCoverage }),
    );
    persistence.testing.setFaults(&completion_store, .{});
    _ = try completion_store.completeDurability();
    try std.testing.expectEqual(@as(usize, 1), completion_context.calls);
    try std.testing.expectError(
        error.NotFresh,
        completion_store.initializeFresh(.{ .context = &completion_context, .run = freshCoverage }),
    );
    try completion_store.shutdown();
    try std.testing.expectError(
        error.StoreClosed,
        completion_store.initializeFresh(.{ .context = &completion_context, .run = freshCoverage }),
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
