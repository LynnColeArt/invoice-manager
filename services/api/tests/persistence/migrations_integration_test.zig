const std = @import("std");
const migrations = @import("migrations");

test "migration integration producer is build-wired" {
    std.testing.refAllDecls(migrations);
}

fn databasePath(allocator: std.mem.Allocator, tmp: *const std.testing.TmpDir) ![]u8 {
    return std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/wp07.shovel", .{tmp.sub_path});
}

fn migrationRoot(io: std.Io) []const u8 {
    var directory = std.Io.Dir.openDir(.cwd(), io, "migrations/p0", .{}) catch
        return "services/api/migrations/p0";
    directory.close(io);
    return "migrations/p0";
}

test "bootstrap applies durably and an identical reopen run is a no-op" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try databasePath(allocator, &tmp);
    defer allocator.free(database_path);

    var store = try migrations.testing.openStoreWithFaults(
        allocator,
        std.testing.io,
        database_path,
        .{},
    );
    const first = try migrations.run(
        allocator,
        std.testing.io,
        &store,
        &.{.{ .owner = "p0", .path = migrationRoot(std.testing.io) }},
        "2026-07-21T12:34:56.789Z",
    );
    try std.testing.expect(first.isReady());
    try std.testing.expectEqual(@as(usize, 1), first.applied_count);
    try std.testing.expectEqual(@as(usize, 0), first.already_applied_count);
    try store.shutdown();

    store = try migrations.testing.openStoreWithFaults(
        allocator,
        std.testing.io,
        database_path,
        .{},
    );
    defer store.shutdown() catch {};
    const second = try migrations.run(
        allocator,
        std.testing.io,
        &store,
        &.{.{ .owner = "p0", .path = migrationRoot(std.testing.io) }},
        "2026-07-21T12:34:56.789Z",
    );
    try std.testing.expect(second.isReady());
    try std.testing.expectEqual(@as(usize, 0), second.applied_count);
    try std.testing.expectEqual(@as(usize, 1), second.already_applied_count);
}

test "applied-history corruption and immutable drift fail through the public runner" {
    const cases = [_]migrations.CriticalCategory{
        .corrupt_applied_history,
        .duplicate_applied_history,
        .applied_id_drift,
        .applied_owner_drift,
        .applied_descriptor_drift,
        .applied_script_drift,
    };
    for (cases) |case| {
        try std.testing.expectError(
            migrations.expectedError(case),
            historyFailure(std.testing.allocator, std.testing.io, case),
        );
    }
}

test "DDL failure discards dirty state reopens durable state and blocks later work" {
    try expectPublicError(error.DdlFailure, ddlFailure(std.testing.allocator, std.testing.io, false));
    try expectPublicError(error.DdlFailure, ddlFailure(std.testing.allocator, std.testing.io, true));
    try reopenFailure(std.testing.allocator, std.testing.io, false);
    try reopenFailure(std.testing.allocator, std.testing.io, true);
}

test "durability completion retries persistence and never replays migration DDL" {
    const cases = [_]migrations.CriticalCategory{
        .checkpoint_failure,
        .directory_sync_failure,
        .unsupported_directory_sync,
    };
    for (cases) |case| {
        const evidence = try completeWithoutReplay(
            std.testing.allocator,
            std.testing.io,
            case,
        );
        try std.testing.expectEqual(@as(usize, 1), evidence.application_calls);
        try std.testing.expect(!evidence.initial.isReady());
        try std.testing.expectEqual(migrations.ReadinessStatus.durability_unconfirmed, evidence.initial.status);
        try std.testing.expectEqual(
            if (case == .checkpoint_failure)
                migrations.CriticalCategory.committed_not_durable
            else
                migrations.CriticalCategory.checkpointed_not_durable,
            evidence.initial.durability_boundary.?,
        );
        try std.testing.expect(!evidence.completed.isReady());
        try std.testing.expectEqual(@as(usize, 1), evidence.application_calls);
    }
}

test "history-read checkpoint completion requires revalidation before pending migration readiness" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    const pending_id = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e50";
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const root_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/p0", .{tmp.sub_path});
    defer allocator.free(root_path);
    try writeMigration(
        allocator,
        io,
        root_path,
        bootstrap_id,
        "bootstrap_migration_history",
        &.{},
        "[]",
        bootstrap_script,
    );
    const database_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/wp07-history-read.shovel", .{tmp.sub_path});
    defer allocator.free(database_path);
    var store = try migrations.testing.openStoreWithFaults(allocator, io, database_path, .{});
    defer store.shutdown() catch {};

    var bootstrap_calls: usize = 0;
    const bootstrap = try migrations.testing.runObserved(
        allocator,
        io,
        &store,
        &.{.{ .owner = "p0", .path = root_path }},
        "2026-07-21T12:34:56.789Z",
        &bootstrap_calls,
    );
    try std.testing.expect(bootstrap.isReady());
    try std.testing.expectEqual(@as(usize, 1), bootstrap_calls);

    try writeMigration(
        allocator,
        io,
        root_path,
        pending_id,
        "pending_after_history",
        &.{bootstrap_id},
        "[\"018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f\"]",
        "CREATE TABLE pending_after_history (id TEXT);\n",
    );
    migrations.testing.setFaults(&store, .{ .checkpoint = true });
    var pending_calls: usize = 0;
    const interrupted = try migrations.testing.runObserved(
        allocator,
        io,
        &store,
        &.{.{ .owner = "p0", .path = root_path }},
        "2026-07-21T12:34:56.789Z",
        &pending_calls,
    );
    try std.testing.expect(!interrupted.isReady());
    try std.testing.expectEqual(migrations.ReadinessStatus.durability_unconfirmed, interrupted.status);
    try std.testing.expectEqual(migrations.CriticalCategory.checkpoint_failure, interrupted.category.?);
    try std.testing.expectEqual(@as(usize, 0), pending_calls);

    migrations.testing.setFaults(&store, .{});
    const completed = try migrations.completeDurability(&store, interrupted);
    const rerun = try migrations.testing.runObserved(
        allocator,
        io,
        &store,
        &.{.{ .owner = "p0", .path = root_path }},
        "2026-07-21T12:34:56.789Z",
        &pending_calls,
    );
    try std.testing.expect(rerun.isReady());
    try std.testing.expectEqual(@as(usize, 1), pending_calls);
    try std.testing.expectEqual(@as(usize, 1), rerun.applied_count);
    try std.testing.expectEqual(@as(usize, 1), rerun.already_applied_count);
    try std.testing.expect(!completed.isReady());
    try std.testing.expectEqualStrings("revalidation_required", @tagName(completed.status));
}

test "early-plan durability completion requires revalidation and never replays committed DDL" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    const pending_id = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e50";
    const FaultCase = struct {
        category: migrations.CriticalCategory,
        faults: migrations.testing.Faults,
        checkpoint_complete: bool,
    };
    const cases = [_]FaultCase{
        .{ .category = .checkpoint_failure, .faults = .{ .checkpoint = true }, .checkpoint_complete = false },
        .{ .category = .directory_sync_failure, .faults = .{ .directory_sync = true }, .checkpoint_complete = true },
        .{ .category = .unsupported_directory_sync, .faults = .{ .unsupported_directory_sync = true }, .checkpoint_complete = true },
    };
    var all_completion_results_require_revalidation = true;
    for (cases) |case| {
        var tmp = std.testing.tmpDir(.{});
        defer tmp.cleanup();
        const root_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/p0", .{tmp.sub_path});
        defer allocator.free(root_path);
        try writeMigration(
            allocator,
            io,
            root_path,
            bootstrap_id,
            "bootstrap_migration_history",
            &.{},
            "[]",
            bootstrap_script,
        );
        try writeMigration(
            allocator,
            io,
            root_path,
            pending_id,
            "pending_after_bootstrap",
            &.{bootstrap_id},
            "[\"018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f\"]",
            "CREATE TABLE pending_after_bootstrap (id TEXT);\n",
        );
        const database_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/wp07-early-plan.shovel", .{tmp.sub_path});
        defer allocator.free(database_path);
        var store = try migrations.testing.openStoreWithFaults(allocator, io, database_path, case.faults);
        defer store.shutdown() catch {};

        var calls: usize = 0;
        const interrupted = try migrations.testing.runObserved(
            allocator,
            io,
            &store,
            &.{.{ .owner = "p0", .path = root_path }},
            "2026-07-21T12:34:56.789Z",
            &calls,
        );
        try std.testing.expect(!interrupted.isReady());
        try std.testing.expectEqual(migrations.ReadinessStatus.durability_unconfirmed, interrupted.status);
        try std.testing.expectEqual(case.category, interrupted.category.?);
        try std.testing.expectEqual(case.checkpoint_complete, interrupted.checkpoint_complete);
        try std.testing.expect(!interrupted.directory_sync_complete);
        try std.testing.expectEqual(@as(usize, 1), calls);

        migrations.testing.setFaults(&store, .{});
        const completed = try migrations.completeDurability(&store, interrupted);
        const rerun = try migrations.testing.runObserved(
            allocator,
            io,
            &store,
            &.{.{ .owner = "p0", .path = root_path }},
            "2026-07-21T12:34:56.789Z",
            &calls,
        );
        try std.testing.expect(rerun.isReady());
        try std.testing.expectEqual(@as(usize, 2), calls);
        try std.testing.expectEqual(@as(usize, 1), rerun.applied_count);
        try std.testing.expectEqual(@as(usize, 1), rerun.already_applied_count);
        all_completion_results_require_revalidation = all_completion_results_require_revalidation and
            !completed.isReady() and
            std.mem.eql(u8, "revalidation_required", @tagName(completed.status));
    }
    try std.testing.expect(all_completion_results_require_revalidation);
}

test "nonempty store without migration history is corruption and executes zero migration DDL" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/wp07-nonempty.shovel", .{tmp.sub_path});
    defer allocator.free(database_path);
    var store = try migrations.testing.openStoreWithFaults(allocator, io, database_path, .{});
    defer store.shutdown() catch {};
    _ = try store.startupWrite(.{ .context = undefined, .run = seedUnrelatedObject });

    var calls: usize = 0;
    var observed_error: ?anyerror = null;
    _ = migrations.testing.runObserved(
        allocator,
        io,
        &store,
        &.{.{ .owner = "p0", .path = migrationRoot(io) }},
        "2026-07-21T12:34:56.789Z",
        &calls,
    ) catch |err| {
        observed_error = err;
    };
    try std.testing.expectEqual(@as(usize, 0), calls);
    try std.testing.expectEqual(error.CorruptAppliedHistory, observed_error.?);
    try std.testing.expectEqual(@as(usize, 1), try migrations.testing.rowCount(
        &store,
        "SELECT body FROM wp07_unrelated;",
    ));
}

test "existing malformed migration history is corruption and executes zero migration DDL" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/wp07-malformed-history.shovel", .{tmp.sub_path});
    defer allocator.free(database_path);
    var store = try migrations.testing.openStoreWithFaults(allocator, io, database_path, .{});
    defer store.shutdown() catch {};
    _ = try store.startupWrite(.{ .context = undefined, .run = seedMalformedHistoryObject });

    var calls: usize = 0;
    var observed_error: ?anyerror = null;
    _ = migrations.testing.runObserved(
        allocator,
        io,
        &store,
        &.{.{ .owner = "p0", .path = migrationRoot(io) }},
        "2026-07-21T12:34:56.789Z",
        &calls,
    ) catch |err| {
        observed_error = err;
    };
    try std.testing.expectEqual(@as(usize, 0), calls);
    try std.testing.expectEqual(error.CorruptAppliedHistory, observed_error.?);
}

test "deleted durable migration history is corruption and executes zero replacement DDL" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/wp07-deleted-history.shovel", .{tmp.sub_path});
    defer allocator.free(database_path);
    var store = try migrations.testing.openStoreWithFaults(allocator, io, database_path, .{});
    defer store.shutdown() catch {};
    var bootstrap_calls: usize = 0;
    const bootstrap = try migrations.testing.runObserved(
        allocator,
        io,
        &store,
        &.{.{ .owner = "p0", .path = migrationRoot(io) }},
        "2026-07-21T12:34:56.789Z",
        &bootstrap_calls,
    );
    try std.testing.expect(bootstrap.isReady());
    try std.testing.expectEqual(@as(usize, 1), bootstrap_calls);
    _ = try store.startupWrite(.{ .context = undefined, .run = deleteHistoryObject });

    var replacement_calls: usize = 0;
    var observed_error: ?anyerror = null;
    _ = migrations.testing.runObserved(
        allocator,
        io,
        &store,
        &.{.{ .owner = "p0", .path = migrationRoot(io) }},
        "2026-07-21T12:34:56.789Z",
        &replacement_calls,
    ) catch |err| {
        observed_error = err;
    };
    try std.testing.expectEqual(@as(usize, 0), replacement_calls);
    try std.testing.expectEqual(error.CorruptAppliedHistory, observed_error.?);
}

fn seedUnrelatedObject(_: *anyopaque, executor: migrations.testing.StartupExecutor) !void {
    _ = try executor.executeScript("CREATE TABLE wp07_unrelated (body TEXT);\n");
    _ = try executor.executeBound(
        &.{ "INSERT INTO wp07_unrelated VALUES (", ");" },
        &.{"durable"},
    );
}

fn seedMalformedHistoryObject(_: *anyopaque, executor: migrations.testing.StartupExecutor) !void {
    _ = try executor.executeScript("CREATE TABLE app_schema_migrations (id TEXT);\n");
}

fn deleteHistoryObject(_: *anyopaque, executor: migrations.testing.StartupExecutor) !void {
    _ = try executor.executeScript("DROP TABLE app_schema_migrations;\n");
}

test "identical rerun executes zero migration DDL and preserves durable history bytes" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/wp07-noop-bytes.shovel", .{tmp.sub_path});
    defer allocator.free(database_path);

    var store = try migrations.testing.openStoreWithFaults(allocator, io, database_path, .{});
    var first_calls: usize = 0;
    const first = try migrations.testing.runObserved(
        allocator,
        io,
        &store,
        &.{.{ .owner = "p0", .path = migrationRoot(io) }},
        "2026-07-21T12:34:56.789Z",
        &first_calls,
    );
    try std.testing.expect(first.isReady());
    try std.testing.expectEqual(@as(usize, 1), first_calls);
    try store.shutdown();
    const before = try std.Io.Dir.readFileAlloc(
        .cwd(),
        io,
        database_path,
        allocator,
        .limited(1024 * 1024),
    );
    defer allocator.free(before);

    store = try migrations.testing.openStoreWithFaults(allocator, io, database_path, .{});
    var second_calls: usize = 0;
    const second = try migrations.testing.runObserved(
        allocator,
        io,
        &store,
        &.{.{ .owner = "p0", .path = migrationRoot(io) }},
        "2030-01-01T00:00:00.000Z",
        &second_calls,
    );
    try std.testing.expect(second.isReady());
    try std.testing.expectEqual(@as(usize, 0), second_calls);
    try std.testing.expectEqual(@as(usize, 0), second.applied_count);
    try std.testing.expectEqual(@as(usize, 1), second.already_applied_count);
    try std.testing.expectEqual(@as(usize, 1), try migrations.testing.rowCount(
        &store,
        "SELECT id, owner, descriptor_digest, script_digest, applied_at FROM app_schema_migrations;",
    ));
    try store.shutdown();
    const after = try std.Io.Dir.readFileAlloc(
        .cwd(),
        io,
        database_path,
        allocator,
        .limited(1024 * 1024),
    );
    defer allocator.free(after);
    try std.testing.expectEqualSlices(u8, before, after);
}

test "partial multi-statement DDL is absent after discard and durable reopen" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    const failed_id = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e50";
    const later_id = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e51";
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const root_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/p0", .{tmp.sub_path});
    defer allocator.free(root_path);
    try writeMigration(
        allocator,
        io,
        root_path,
        bootstrap_id,
        "bootstrap_migration_history",
        &.{},
        "[]",
        bootstrap_script,
    );
    const database_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/wp07-partial.shovel", .{tmp.sub_path});
    defer allocator.free(database_path);
    var store = try migrations.testing.openStoreWithFaults(allocator, io, database_path, .{});
    var bootstrap_calls: usize = 0;
    const bootstrap = try migrations.testing.runObserved(
        allocator,
        io,
        &store,
        &.{.{ .owner = "p0", .path = root_path }},
        "2026-07-21T12:34:56.789Z",
        &bootstrap_calls,
    );
    try std.testing.expect(bootstrap.isReady());
    try store.shutdown();
    const before = try std.Io.Dir.readFileAlloc(
        .cwd(),
        io,
        database_path,
        allocator,
        .limited(1024 * 1024),
    );
    defer allocator.free(before);

    try writeMigration(
        allocator,
        io,
        root_path,
        failed_id,
        "partial_then_fail",
        &.{bootstrap_id},
        "[\"018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f\"]",
        "CREATE TABLE wp07_partial_visible (body TEXT);\nCREATE TABLE broken (\n",
    );
    try writeMigration(
        allocator,
        io,
        root_path,
        later_id,
        "later_after_failure",
        &.{failed_id},
        "[\"018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e50\"]",
        "CREATE TABLE wp07_later_after_failure (body TEXT);\n",
    );
    store = try migrations.testing.openStoreWithFaults(allocator, io, database_path, .{});
    defer store.shutdown() catch {};
    var failed_calls: usize = 0;
    var observed_error: ?anyerror = null;
    var diagnostic = migrations.RunDiagnostic{};
    _ = migrations.testing.runObservedWithDiagnostic(
        allocator,
        io,
        &store,
        &.{.{ .owner = "p0", .path = root_path }},
        "2026-07-21T12:34:56.789Z",
        &failed_calls,
        &diagnostic,
    ) catch |err| {
        observed_error = err;
    };
    try std.testing.expectEqual(error.DdlFailure, observed_error.?);
    try std.testing.expectEqual(migrations.CriticalCategory.ddl_failure, diagnostic.primary.?);
    try std.testing.expectEqual(migrations.CriticalCategory.later_migration_blocked, diagnostic.consequence.?);
    try std.testing.expectEqual(@as(usize, 1), failed_calls);
    try std.testing.expectEqual(.ready, store.state());
    try std.testing.expect(migrations.testing.discardCount(&store) > 0);
    try std.testing.expect(migrations.testing.reopenCount(&store) > 0);
    try std.testing.expectEqual(@as(usize, 1), try migrations.testing.rowCount(
        &store,
        "SELECT id FROM app_schema_migrations;",
    ));
    try std.testing.expectError(
        error.QueryFailed,
        migrations.testing.rowCount(&store, "SELECT body FROM wp07_partial_visible;"),
    );
    try std.testing.expectError(
        error.QueryFailed,
        migrations.testing.rowCount(&store, "SELECT body FROM wp07_later_after_failure;"),
    );
    try store.shutdown();
    const after = try std.Io.Dir.readFileAlloc(
        .cwd(),
        io,
        database_path,
        allocator,
        .limited(1024 * 1024),
    );
    defer allocator.free(after);
    try std.testing.expectEqualSlices(u8, before, after);
}

const CompletionEvidence = struct {
    initial: migrations.Readiness,
    completed: migrations.Readiness,
    application_calls: usize,
};

fn completeWithoutReplay(
    allocator: std.mem.Allocator,
    io: std.Io,
    category: migrations.CriticalCategory,
) !CompletionEvidence {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/wp07-complete.shovel", .{tmp.sub_path});
    defer allocator.free(database_path);
    const faults: migrations.testing.Faults = switch (category) {
        .checkpoint_failure => .{ .checkpoint = true },
        .directory_sync_failure => .{ .directory_sync = true },
        .unsupported_directory_sync => .{ .unsupported_directory_sync = true },
        else => return migrations.expectedError(category),
    };
    var store = try migrations.testing.openStoreWithFaults(allocator, io, database_path, faults);
    defer store.shutdown() catch {};
    var calls: usize = 0;
    const initial = try migrations.testing.runObserved(
        allocator,
        io,
        &store,
        &.{.{ .owner = "p0", .path = migrationRoot(io) }},
        "2026-07-21T12:34:56.789Z",
        &calls,
    );
    migrations.testing.setFaults(&store, .{});
    const completed = try migrations.completeDurability(&store, initial);
    return .{ .initial = initial, .completed = completed, .application_calls = calls };
}

const bootstrap_id = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f";
const bootstrap_script_digest = "sha256:68dff6daa265a0c0c6d603994438c43a0af3228fff72e677d9dcd0cd60b1fbd3";
const bootstrap_descriptor_digest = "sha256:0b5af56a66a73c1f0f96b76ad4307a6e3a76f3cd34cb0ba71197a5e90d4e7877";
const bootstrap_script = "CREATE TABLE app_schema_migrations (id TEXT, owner TEXT, descriptor_digest TEXT, script_digest TEXT, applied_at TEXT);\n";

const SeedRow = struct {
    id: []const u8,
    owner: []const u8,
    descriptor_digest: []const u8,
    script_digest: []const u8,
    applied_at: []const u8 = "2026-07-21T12:34:56.789Z",
};

const SeedContext = struct {
    rows: []const SeedRow,
};

fn seedHistory(raw_context: *anyopaque, executor: migrations.testing.StartupExecutor) !void {
    const context: *SeedContext = @ptrCast(@alignCast(raw_context));
    _ = try executor.executeScript(bootstrap_script);
    for (context.rows) |row| {
        _ = try executor.executeBound(
            &.{
                "INSERT INTO app_schema_migrations VALUES (",
                ", ",
                ", ",
                ", ",
                ", ",
                ");",
            },
            &.{ row.id, row.owner, row.descriptor_digest, row.script_digest, row.applied_at },
        );
    }
}

fn historyFailure(
    allocator: std.mem.Allocator,
    io: std.Io,
    category: migrations.CriticalCategory,
) !void {
    const alternate_id = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e40";
    const bad_digest = "sha256:0000000000000000000000000000000000000000000000000000000000000000";
    const primary: SeedRow = switch (category) {
        .corrupt_applied_history => .{ .id = "not-a-uuid", .owner = "p0", .descriptor_digest = bootstrap_descriptor_digest, .script_digest = bootstrap_script_digest },
        .applied_id_drift => .{ .id = alternate_id, .owner = "p0", .descriptor_digest = bootstrap_descriptor_digest, .script_digest = bootstrap_script_digest },
        .applied_owner_drift => .{ .id = bootstrap_id, .owner = "p1", .descriptor_digest = bootstrap_descriptor_digest, .script_digest = bootstrap_script_digest },
        .applied_descriptor_drift => .{ .id = bootstrap_id, .owner = "p0", .descriptor_digest = bad_digest, .script_digest = bootstrap_script_digest },
        .applied_script_drift => .{ .id = bootstrap_id, .owner = "p0", .descriptor_digest = bootstrap_descriptor_digest, .script_digest = bad_digest },
        .duplicate_applied_history => .{ .id = bootstrap_id, .owner = "p0", .descriptor_digest = bootstrap_descriptor_digest, .script_digest = bootstrap_script_digest },
        else => return migrations.expectedError(category),
    };
    const rows = if (category == .duplicate_applied_history)
        &[_]SeedRow{ primary, primary }
    else
        &[_]SeedRow{primary};
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/wp07-history.shovel", .{tmp.sub_path});
    defer allocator.free(database_path);
    var store = try migrations.testing.openStoreWithFaults(allocator, io, database_path, .{});
    defer store.shutdown() catch {};
    var seed = SeedContext{ .rows = rows };
    _ = try store.startupWrite(.{ .context = &seed, .run = seedHistory });
    _ = try migrations.run(
        allocator,
        io,
        &store,
        &.{.{ .owner = "p0", .path = migrationRoot(io) }},
        "2026-07-21T12:34:56.789Z",
    );
}

fn reopenFailure(allocator: std.mem.Allocator, io: std.Io, quarantine: bool) !void {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/wp07-reopen.shovel", .{tmp.sub_path});
    defer allocator.free(database_path);
    var store = try migrations.testing.openStoreWithFaults(allocator, io, database_path, .{ .reopen = true });
    defer store.shutdown() catch {};
    var observed_error: ?anyerror = null;
    var diagnostic = migrations.RunDiagnostic{};
    _ = migrations.runWithDiagnostic(
        allocator,
        io,
        &store,
        &.{.{ .owner = "p0", .path = migrationRoot(io) }},
        "2026-07-21T12:34:56.789Z",
        &diagnostic,
    ) catch |err| {
        observed_error = err;
    };
    try std.testing.expectEqual(error.ReopenFailure, observed_error.?);
    try std.testing.expectEqual(migrations.CriticalCategory.reopen_failure, diagnostic.primary.?);
    try std.testing.expectEqual(migrations.CriticalCategory.recovery_quarantine, diagnostic.consequence.?);
    if (quarantine) {
        try std.testing.expectEqual(.quarantined, store.state());
        try std.testing.expect(migrations.testing.discardCount(&store) > 0);
        try std.testing.expectEqual(@as(usize, 0), migrations.testing.reopenCount(&store));
    }
}

fn sha256Wire(bytes: []const u8, output: *[71]u8) []const u8 {
    @memcpy(output[0..7], "sha256:");
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    const hex = std.fmt.bytesToHex(digest, .lower);
    @memcpy(output[7..], &hex);
    return output;
}

fn writeMigration(
    allocator: std.mem.Allocator,
    io: std.Io,
    root_path: []const u8,
    id: []const u8,
    name: []const u8,
    dependencies: []const []const u8,
    dependencies_json: []const u8,
    script: []const u8,
) !void {
    const migration_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ root_path, id });
    defer allocator.free(migration_path);
    try std.Io.Dir.createDirPath(.cwd(), io, migration_path);
    const script_path = try std.fmt.allocPrint(allocator, "{s}/up.sql", .{migration_path});
    defer allocator.free(script_path);
    try std.Io.Dir.writeFile(.cwd(), io, .{ .sub_path = script_path, .data = script });

    var script_buffer: [71]u8 = undefined;
    const script_digest = sha256Wire(script, &script_buffer);
    const projection = try migrations.canonicalProjection(
        allocator,
        id,
        "p0",
        name,
        dependencies,
        "up.sql",
        script_digest,
    );
    defer allocator.free(projection);
    var descriptor_buffer: [71]u8 = undefined;
    const descriptor_digest = sha256Wire(projection, &descriptor_buffer);
    const manifest = try std.fmt.allocPrint(
        allocator,
        "{{\"id\":\"{s}\",\"owner\":\"p0\",\"name\":\"{s}\",\"depends_on\":{s},\"script_path\":\"up.sql\",\"script_digest\":\"{s}\",\"descriptor_digest\":\"{s}\"}}",
        .{ id, name, dependencies_json, script_digest, descriptor_digest },
    );
    defer allocator.free(manifest);
    const manifest_path = try std.fmt.allocPrint(allocator, "{s}/manifest.json", .{migration_path});
    defer allocator.free(manifest_path);
    try std.Io.Dir.writeFile(.cwd(), io, .{ .sub_path = manifest_path, .data = manifest });
}

fn ddlFailure(allocator: std.mem.Allocator, io: std.Io, expect_later_blocked: bool) !void {
    const bad_id = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e50";
    const later_id = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e51";
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const root_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/p0", .{tmp.sub_path});
    defer allocator.free(root_path);
    try writeMigration(allocator, io, root_path, bootstrap_id, "bootstrap_migration_history", &.{}, "[]", bootstrap_script);
    try writeMigration(
        allocator,
        io,
        root_path,
        bad_id,
        "invalid_ddl",
        &.{bootstrap_id},
        "[\"018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f\"]",
        "CREATE TABLE broken (\n",
    );
    if (expect_later_blocked) {
        try writeMigration(
            allocator,
            io,
            root_path,
            later_id,
            "later_migration",
            &.{bad_id},
            "[\"018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e50\"]",
            "CREATE TABLE later_migration (id TEXT);\n",
        );
    }
    const database_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/wp07-ddl.shovel", .{tmp.sub_path});
    defer allocator.free(database_path);
    var store = try migrations.testing.openStoreWithFaults(allocator, io, database_path, .{});
    defer store.shutdown() catch {};
    var diagnostic = migrations.RunDiagnostic{};
    _ = migrations.runWithDiagnostic(
        allocator,
        io,
        &store,
        &.{.{ .owner = "p0", .path = root_path }},
        "2026-07-21T12:34:56.789Z",
        &diagnostic,
    ) catch |err| {
        try std.testing.expect(migrations.testing.discardCount(&store) > 0);
        try std.testing.expect(migrations.testing.reopenCount(&store) > 0);
        try std.testing.expectEqual(migrations.CriticalCategory.ddl_failure, diagnostic.primary.?);
        if (expect_later_blocked) {
            try std.testing.expectEqual(migrations.CriticalCategory.later_migration_blocked, diagnostic.consequence.?);
        } else {
            try std.testing.expectEqual(@as(?migrations.CriticalCategory, null), diagnostic.consequence);
        }
        return err;
    };
    return error.TestUnexpectedResult;
}

pub fn exerciseCritical(
    allocator: std.mem.Allocator,
    io: std.Io,
    category: migrations.CriticalCategory,
) !void {
    return switch (category) {
        .discovery_failure => expectPublicError(error.DiscoveryFailure, discoveryFailure(allocator, io, .{ .owner = "p0", .path = "missing/p0" })),
        .missing_manifest,
        .missing_script,
        .malformed_manifest,
        .unknown_descriptor_field,
        .invalid_uuid,
        .owner_mismatch,
        .directory_mismatch,
        .symlink_escape,
        .noncanonical_dependencies,
        .script_digest_mismatch,
        .descriptor_digest_mismatch,
        => expectPublicError(migrations.expectedError(category), fixtureFailure(allocator, io, category)),
        .path_traversal => expectPublicError(error.PathTraversal, discoveryFailure(allocator, io, .{ .owner = "p0", .path = "migrations/../p0" })),
        .duplicate_migration_id,
        .duplicate_descriptor_path,
        .missing_dependency,
        .self_dependency,
        .dependency_cycle,
        .graph_capacity_exceeded,
        => expectPublicError(migrations.expectedError(category), graphFailure(allocator, category)),
        .corrupt_applied_history,
        .duplicate_applied_history,
        .applied_id_drift,
        .applied_owner_drift,
        .applied_descriptor_drift,
        .applied_script_drift,
        => expectPublicError(migrations.expectedError(category), historyFailure(allocator, io, category)),
        .ddl_failure => expectPublicError(error.DdlFailure, ddlFailure(allocator, io, false)),
        .later_migration_blocked => expectPublicError(error.DdlFailure, ddlFailure(allocator, io, true)),
        .reopen_failure => reopenFailure(allocator, io, false),
        .recovery_quarantine => reopenFailure(allocator, io, true),
        .checkpoint_failure,
        .committed_not_durable,
        .durability_unconfirmed,
        => completionFailure(allocator, io, category, .checkpoint_failure),
        .directory_sync_failure,
        .checkpointed_not_durable,
        => completionFailure(allocator, io, category, .directory_sync_failure),
        .unsupported_directory_sync => completionFailure(allocator, io, category, .unsupported_directory_sync),
        .allocation_failure_cleanup => expectPublicError(error.AllocationFailureCleanup, allocationFailureScenario(allocator, io)),
    };
}

fn expectPublicError(expected: anyerror, result: anytype) !void {
    _ = result catch |observed| {
        try std.testing.expectEqual(expected, observed);
        return;
    };
    return error.TestUnexpectedResult;
}

fn completionFailure(
    allocator: std.mem.Allocator,
    io: std.Io,
    category: migrations.CriticalCategory,
    fault: migrations.CriticalCategory,
) !void {
    const evidence = try completeWithoutReplay(allocator, io, fault);
    try std.testing.expectEqual(@as(usize, 1), evidence.application_calls);
    try std.testing.expectEqual(migrations.ReadinessStatus.durability_unconfirmed, evidence.initial.status);
    switch (category) {
        .checkpoint_failure, .directory_sync_failure, .unsupported_directory_sync => try std.testing.expectEqual(category, evidence.initial.category.?),
        .durability_unconfirmed => try std.testing.expectEqual(migrations.ReadinessStatus.durability_unconfirmed, evidence.initial.status),
        .committed_not_durable => {
            try std.testing.expect(!evidence.initial.checkpoint_complete);
            try std.testing.expect(!evidence.initial.directory_sync_complete);
        },
        .checkpointed_not_durable => {
            try std.testing.expect(evidence.initial.checkpoint_complete);
            try std.testing.expect(!evidence.initial.directory_sync_complete);
        },
        else => return error.TestUnexpectedResult,
    }
    try std.testing.expect(!evidence.completed.isReady());
}

fn discoveryFailure(allocator: std.mem.Allocator, io: std.Io, root: migrations.OwnerRoot) !void {
    var discovered = try migrations.discover(allocator, io, &.{root});
    discovered.deinit();
    return error.TestUnexpectedResult;
}

fn fixtureFailure(
    allocator: std.mem.Allocator,
    io: std.Io,
    category: migrations.CriticalCategory,
) !void {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const root_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/p0", .{tmp.sub_path});
    defer allocator.free(root_path);
    const invalid_id = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4F";
    const directory_id = if (category == .invalid_uuid) invalid_id else bootstrap_id;
    const migration_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ root_path, directory_id });
    defer allocator.free(migration_path);
    try std.Io.Dir.createDirPath(.cwd(), io, migration_path);
    if (category == .symlink_escape) {
        const link_path = try std.fmt.allocPrint(allocator, "{s}/escape", .{root_path});
        defer allocator.free(link_path);
        try std.Io.Dir.symLink(.cwd(), io, "..", link_path, .{});
        return discoveryFailure(allocator, io, .{ .owner = "p0", .path = root_path });
    }
    if (category == .missing_manifest) {
        return discoveryFailure(allocator, io, .{ .owner = "p0", .path = root_path });
    }
    const manifest_path = try std.fmt.allocPrint(allocator, "{s}/manifest.json", .{migration_path});
    defer allocator.free(manifest_path);
    const valid_manifest =
        "{\"id\":\"018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f\",\"owner\":\"p0\",\"name\":\"bootstrap_migration_history\",\"depends_on\":[],\"script_path\":\"up.sql\",\"script_digest\":\"sha256:68dff6daa265a0c0c6d603994438c43a0af3228fff72e677d9dcd0cd60b1fbd3\",\"descriptor_digest\":\"sha256:0b5af56a66a73c1f0f96b76ad4307a6e3a76f3cd34cb0ba71197a5e90d4e7877\"}";
    const manifest = switch (category) {
        .malformed_manifest => "{",
        .unknown_descriptor_field => "{\"id\":\"018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f\",\"owner\":\"p0\",\"name\":\"bootstrap_migration_history\",\"depends_on\":[],\"script_path\":\"up.sql\",\"script_digest\":\"sha256:68dff6daa265a0c0c6d603994438c43a0af3228fff72e677d9dcd0cd60b1fbd3\",\"descriptor_digest\":\"sha256:0b5af56a66a73c1f0f96b76ad4307a6e3a76f3cd34cb0ba71197a5e90d4e7877\",\"extra\":true}",
        .invalid_uuid => "{\"id\":\"018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4F\",\"owner\":\"p0\",\"name\":\"bootstrap_migration_history\",\"depends_on\":[],\"script_path\":\"up.sql\",\"script_digest\":\"sha256:68dff6daa265a0c0c6d603994438c43a0af3228fff72e677d9dcd0cd60b1fbd3\",\"descriptor_digest\":\"sha256:0b5af56a66a73c1f0f96b76ad4307a6e3a76f3cd34cb0ba71197a5e90d4e7877\"}",
        .owner_mismatch => "{\"id\":\"018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f\",\"owner\":\"p1\",\"name\":\"bootstrap_migration_history\",\"depends_on\":[],\"script_path\":\"up.sql\",\"script_digest\":\"sha256:68dff6daa265a0c0c6d603994438c43a0af3228fff72e677d9dcd0cd60b1fbd3\",\"descriptor_digest\":\"sha256:0b5af56a66a73c1f0f96b76ad4307a6e3a76f3cd34cb0ba71197a5e90d4e7877\"}",
        .directory_mismatch => "{\"id\":\"018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e40\",\"owner\":\"p0\",\"name\":\"bootstrap_migration_history\",\"depends_on\":[],\"script_path\":\"up.sql\",\"script_digest\":\"sha256:68dff6daa265a0c0c6d603994438c43a0af3228fff72e677d9dcd0cd60b1fbd3\",\"descriptor_digest\":\"sha256:0b5af56a66a73c1f0f96b76ad4307a6e3a76f3cd34cb0ba71197a5e90d4e7877\"}",
        .noncanonical_dependencies => "{\"id\":\"018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f\",\"owner\":\"p0\",\"name\":\"bootstrap_migration_history\",\"depends_on\":[\"018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e51\",\"018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e50\"],\"script_path\":\"up.sql\",\"script_digest\":\"sha256:68dff6daa265a0c0c6d603994438c43a0af3228fff72e677d9dcd0cd60b1fbd3\",\"descriptor_digest\":\"sha256:0b5af56a66a73c1f0f96b76ad4307a6e3a76f3cd34cb0ba71197a5e90d4e7877\"}",
        .descriptor_digest_mismatch => "{\"id\":\"018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f\",\"owner\":\"p0\",\"name\":\"bootstrap_migration_history\",\"depends_on\":[],\"script_path\":\"up.sql\",\"script_digest\":\"sha256:68dff6daa265a0c0c6d603994438c43a0af3228fff72e677d9dcd0cd60b1fbd3\",\"descriptor_digest\":\"sha256:0000000000000000000000000000000000000000000000000000000000000000\"}",
        else => valid_manifest,
    };
    try std.Io.Dir.writeFile(.cwd(), io, .{ .sub_path = manifest_path, .data = manifest });
    if (category != .missing_script) {
        const script_path = try std.fmt.allocPrint(allocator, "{s}/up.sql", .{migration_path});
        defer allocator.free(script_path);
        const script = if (category == .script_digest_mismatch)
            "CREATE TABLE app_schema_migrations_changed (body TEXT);\n"
        else
            bootstrap_script;
        try std.Io.Dir.writeFile(.cwd(), io, .{ .sub_path = script_path, .data = script });
    }
    return discoveryFailure(allocator, io, .{ .owner = "p0", .path = root_path });
}

fn borrowedDescriptor(
    id: []const u8,
    dependencies: []const []const u8,
    source_path: []const u8,
) migrations.Descriptor {
    return .{
        .id = @constCast(id),
        .owner = @constCast("p0"),
        .name = @constCast("negative_graph"),
        .depends_on = @ptrCast(@constCast(dependencies)),
        .script_path = @constCast("up.sql"),
        .script_digest = @constCast(bootstrap_script_digest),
        .descriptor_digest = @constCast(bootstrap_descriptor_digest),
        .script = @constCast("CREATE TABLE negative_graph (body TEXT);\n"),
        .source_path = @constCast(source_path),
    };
}

fn graphFailure(allocator: std.mem.Allocator, category: migrations.CriticalCategory) !void {
    const a = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e40";
    const b = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e41";
    if (category == .graph_capacity_exceeded) {
        const oversized = try allocator.alloc(migrations.Descriptor, 1025);
        defer allocator.free(oversized);
        var result = try migrations.plan(allocator, oversized);
        result.deinit();
        return error.TestUnexpectedResult;
    }
    const descriptors: [2]migrations.Descriptor = switch (category) {
        .duplicate_migration_id => .{
            borrowedDescriptor(a, &.{}, "p0/a/manifest.json"),
            borrowedDescriptor(a, &.{}, "p1/a/manifest.json"),
        },
        .duplicate_descriptor_path => .{
            borrowedDescriptor(a, &.{}, "p0/a/manifest.json"),
            borrowedDescriptor(b, &.{}, "p0/a/manifest.json"),
        },
        .missing_dependency => .{
            borrowedDescriptor(a, &.{b}, "p0/a/manifest.json"),
            borrowedDescriptor("018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e42", &.{}, "p0/c/manifest.json"),
        },
        .self_dependency => .{
            borrowedDescriptor(a, &.{a}, "p0/a/manifest.json"),
            borrowedDescriptor(b, &.{}, "p0/b/manifest.json"),
        },
        .dependency_cycle => .{
            borrowedDescriptor(a, &.{b}, "p0/a/manifest.json"),
            borrowedDescriptor(b, &.{a}, "p0/b/manifest.json"),
        },
        else => return migrations.expectedError(category),
    };
    var diagnostic = migrations.PlanDiagnostic{};
    var result = try migrations.planWithDiagnostic(allocator, &descriptors, &diagnostic);
    result.deinit();
    return error.TestUnexpectedResult;
}

fn allocationFailureScenario(allocator: std.mem.Allocator, io: std.Io) !void {
    var observed = false;
    for (0..128) |failure_index| {
        var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = failure_index });
        var discovered = migrations.discover(
            failing.allocator(),
            io,
            &.{.{ .owner = "p0", .path = migrationRoot(io) }},
        ) catch |err| {
            if (err == error.AllocationFailureCleanup) observed = true;
            continue;
        };
        discovered.deinit();
    }
    try std.testing.expect(observed);
    return error.AllocationFailureCleanup;
}
