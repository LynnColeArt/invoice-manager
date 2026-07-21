const std = @import("std");
const migrations = @import("migrations");

test "migration production declarations are analyzed" {
    std.testing.refAllDecls(migrations);
}

test "critical branch: discovery_failure" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .discovery_failure);
}

test "critical branch: missing_manifest" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .missing_manifest);
}

test "critical branch: missing_script" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .missing_script);
}

test "critical branch: malformed_manifest" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .malformed_manifest);
}

test "critical branch: unknown_descriptor_field" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .unknown_descriptor_field);
}

test "critical branch: invalid_uuid" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .invalid_uuid);
}

test "critical branch: owner_mismatch" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .owner_mismatch);
}

test "critical branch: directory_mismatch" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .directory_mismatch);
}

test "critical branch: path_traversal" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .path_traversal);
}

test "critical branch: symlink_escape" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .symlink_escape);
}

test "critical branch: noncanonical_dependencies" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .noncanonical_dependencies);
}

test "critical branch: script_digest_mismatch" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .script_digest_mismatch);
}

test "critical branch: descriptor_digest_mismatch" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .descriptor_digest_mismatch);
}

test "critical branch: duplicate_migration_id" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .duplicate_migration_id);
}

test "critical branch: duplicate_descriptor_path" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .duplicate_descriptor_path);
}

test "critical branch: missing_dependency" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .missing_dependency);
}

test "critical branch: self_dependency" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .self_dependency);
}

test "critical branch: dependency_cycle" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .dependency_cycle);
}

test "critical branch: graph_capacity_exceeded" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .graph_capacity_exceeded);
}

test "critical branch: corrupt_applied_history" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .corrupt_applied_history);
}

test "critical branch: duplicate_applied_history" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .duplicate_applied_history);
}

test "critical branch: applied_id_drift" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .applied_id_drift);
}

test "critical branch: applied_owner_drift" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .applied_owner_drift);
}

test "critical branch: applied_descriptor_drift" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .applied_descriptor_drift);
}

test "critical branch: applied_script_drift" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .applied_script_drift);
}

test "critical branch: ddl_failure" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .ddl_failure);
}

test "critical branch: checkpoint_failure" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .checkpoint_failure);
}

test "critical branch: directory_sync_failure" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .directory_sync_failure);
}

test "critical branch: reopen_failure" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .reopen_failure);
}

test "critical branch: recovery_quarantine" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .recovery_quarantine);
}

test "critical branch: durability_unconfirmed" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .durability_unconfirmed);
}

test "critical branch: unsupported_directory_sync" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .unsupported_directory_sync);
}

test "critical branch: committed_not_durable" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .committed_not_durable);
}

test "critical branch: checkpointed_not_durable" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .checkpointed_not_durable);
}

test "critical branch: later_migration_blocked" {
    try exerciseCritical(std.testing.allocator, std.testing.io, .later_migration_blocked);
}

test "critical branch: allocation_failure_cleanup" {
    try expectPublicError(error.AllocationFailureCleanup, allocationFailureScenario(std.testing.allocator, std.testing.io));
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
        else => return error.TestUnexpectedResult,
    };
    var store = try migrations.testing.openStoreWithFaults(allocator, io, database_path, faults);
    defer store.shutdown() catch {};
    var calls: usize = 0;
    const initial = try migrations.testing.runObserved(
        allocator,
        io,
        &store,
        &.{.{ .owner = "p0", .path = "migrations/p0" }},
        "2026-07-21T12:34:56.789Z",
        &calls,
    );
    try std.testing.expect(!initial.isReady());
    try std.testing.expectEqual(.uncertain, store.state());
    const diagnostic = store.lastDiagnostic() orelse return error.TestUnexpectedResult;
    switch (category) {
        .checkpoint_failure => try std.testing.expectEqual(.checkpoint_failure, diagnostic.category),
        .directory_sync_failure => try std.testing.expectEqual(.directory_sync_failure, diagnostic.category),
        .unsupported_directory_sync => try std.testing.expectEqual(.unsupported_directory_sync, diagnostic.category),
        else => return error.TestUnexpectedResult,
    }
    migrations.testing.setFaults(&store, .{});
    const completed = try migrations.completeDurability(&store, initial);
    try std.testing.expectEqual(.ready, store.state());
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

const RawSeedContext = struct {
    schema: []const u8,
    insert: []const u8,
};

fn seedRawHistory(raw_context: *anyopaque, executor: migrations.testing.StartupExecutor) !void {
    const context: *RawSeedContext = @ptrCast(@alignCast(raw_context));
    _ = try executor.executeScript(context.schema);
    _ = try executor.executeScript(context.insert);
}

fn expectRawHistoryFailure(
    allocator: std.mem.Allocator,
    io: std.Io,
    schema: []const u8,
    insert: []const u8,
) !void {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/wp07-raw-history.shovel", .{tmp.sub_path});
    defer allocator.free(database_path);
    var store = try migrations.testing.openStoreWithFaults(allocator, io, database_path, .{});
    defer store.shutdown() catch {};
    var seed = RawSeedContext{ .schema = schema, .insert = insert };
    _ = try store.startupWrite(.{ .context = &seed, .run = seedRawHistory });
    try std.testing.expectError(
        error.CorruptAppliedHistory,
        migrations.run(
            allocator,
            io,
            &store,
            &.{.{ .owner = "p0", .path = "migrations/p0" }},
            "2026-07-21T12:34:56.789Z",
        ),
    );
}

fn expectSeedRowsFailure(allocator: std.mem.Allocator, io: std.Io, rows: []const SeedRow) !void {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/wp07-invalid-history.shovel", .{tmp.sub_path});
    defer allocator.free(database_path);
    var store = try migrations.testing.openStoreWithFaults(allocator, io, database_path, .{});
    defer store.shutdown() catch {};
    var seed = SeedContext{ .rows = rows };
    _ = try store.startupWrite(.{ .context = &seed, .run = seedHistory });
    try std.testing.expectError(
        error.CorruptAppliedHistory,
        migrations.run(
            allocator,
            io,
            &store,
            &.{.{ .owner = "p0", .path = "migrations/p0" }},
            "2026-07-21T12:34:56.789Z",
        ),
    );
}

fn exerciseHistoryShapeSweep(allocator: std.mem.Allocator, io: std.Io) !void {
    const RawCase = struct { schema: []const u8, insert: []const u8 };
    const type_cases = [_]RawCase{
        .{
            .schema = "CREATE TABLE app_schema_migrations (id INTEGER, owner TEXT, descriptor_digest TEXT, script_digest TEXT, applied_at TEXT);",
            .insert = "INSERT INTO app_schema_migrations VALUES (1, 'p0', 'sha256:0b5af56a66a73c1f0f96b76ad4307a6e3a76f3cd34cb0ba71197a5e90d4e7877', 'sha256:68dff6daa265a0c0c6d603994438c43a0af3228fff72e677d9dcd0cd60b1fbd3', '2026-07-21T12:34:56.789Z');",
        },
        .{
            .schema = "CREATE TABLE app_schema_migrations (id TEXT, owner INTEGER, descriptor_digest TEXT, script_digest TEXT, applied_at TEXT);",
            .insert = "INSERT INTO app_schema_migrations VALUES ('018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f', 1, 'sha256:0b5af56a66a73c1f0f96b76ad4307a6e3a76f3cd34cb0ba71197a5e90d4e7877', 'sha256:68dff6daa265a0c0c6d603994438c43a0af3228fff72e677d9dcd0cd60b1fbd3', '2026-07-21T12:34:56.789Z');",
        },
        .{
            .schema = "CREATE TABLE app_schema_migrations (id TEXT, owner TEXT, descriptor_digest INTEGER, script_digest TEXT, applied_at TEXT);",
            .insert = "INSERT INTO app_schema_migrations VALUES ('018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f', 'p0', 1, 'sha256:68dff6daa265a0c0c6d603994438c43a0af3228fff72e677d9dcd0cd60b1fbd3', '2026-07-21T12:34:56.789Z');",
        },
        .{
            .schema = "CREATE TABLE app_schema_migrations (id TEXT, owner TEXT, descriptor_digest TEXT, script_digest INTEGER, applied_at TEXT);",
            .insert = "INSERT INTO app_schema_migrations VALUES ('018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f', 'p0', 'sha256:0b5af56a66a73c1f0f96b76ad4307a6e3a76f3cd34cb0ba71197a5e90d4e7877', 1, '2026-07-21T12:34:56.789Z');",
        },
        .{
            .schema = "CREATE TABLE app_schema_migrations (id TEXT, owner TEXT, descriptor_digest TEXT, script_digest TEXT, applied_at INTEGER);",
            .insert = "INSERT INTO app_schema_migrations VALUES ('018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f', 'p0', 'sha256:0b5af56a66a73c1f0f96b76ad4307a6e3a76f3cd34cb0ba71197a5e90d4e7877', 'sha256:68dff6daa265a0c0c6d603994438c43a0af3228fff72e677d9dcd0cd60b1fbd3', 1);",
        },
    };
    for (type_cases) |case| try expectRawHistoryFailure(allocator, io, case.schema, case.insert);

    const bad_digest = "bad";
    try expectSeedRowsFailure(allocator, io, &.{.{
        .id = bootstrap_id,
        .owner = "p0",
        .descriptor_digest = bad_digest,
        .script_digest = bootstrap_script_digest,
    }});
    try expectSeedRowsFailure(allocator, io, &.{.{
        .id = bootstrap_id,
        .owner = "p0",
        .descriptor_digest = bootstrap_descriptor_digest,
        .script_digest = bad_digest,
    }});
    try expectSeedRowsFailure(allocator, io, &.{.{
        .id = bootstrap_id,
        .owner = "p0",
        .descriptor_digest = bootstrap_descriptor_digest,
        .script_digest = bootstrap_script_digest,
        .applied_at = "bad",
    }});
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
        else => return error.TestUnexpectedResult,
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
        &.{.{ .owner = "p0", .path = "migrations/p0" }},
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
    _ = migrations.run(
        allocator,
        io,
        &store,
        &.{.{ .owner = "p0", .path = "migrations/p0" }},
        "2026-07-21T12:34:56.789Z",
    ) catch |err| {
        try std.testing.expectEqual(error.ReopenFailure, err);
        if (quarantine) {
            try std.testing.expectEqual(.quarantined, store.state());
            const diagnostic = store.lastDiagnostic() orelse return error.TestUnexpectedResult;
            try std.testing.expectEqual(.reopen_failure, diagnostic.category);
            try std.testing.expectEqual(.quarantined, diagnostic.state);
            try std.testing.expectEqual(@as(usize, 1), migrations.testing.discardCount(&store));
            try std.testing.expectEqual(@as(usize, 0), migrations.testing.reopenCount(&store));
        }
        return;
    };
    return error.TestUnexpectedResult;
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
    var application_calls: usize = 0;
    _ = migrations.testing.runObserved(
        allocator,
        io,
        &store,
        &.{.{ .owner = "p0", .path = root_path }},
        "2026-07-21T12:34:56.789Z",
        &application_calls,
    ) catch |err| {
        try std.testing.expectEqual(error.DdlFailure, err);
        try std.testing.expectEqual(@as(usize, 2), migrations.testing.discardCount(&store));
        try std.testing.expectEqual(@as(usize, 2), migrations.testing.reopenCount(&store));
        try std.testing.expectEqual(.ready, store.state());
        try std.testing.expectEqual(@as(usize, 2), application_calls);
        try std.testing.expectEqual(
            @as(usize, 1),
            try migrations.testing.rowCount(&store, "SELECT * FROM app_schema_migrations;"),
        );
        if (expect_later_blocked) {
            try std.testing.expectError(
                error.QueryFailed,
                migrations.testing.rowCount(&store, "SELECT * FROM later_migration;"),
            );
        }
        return;
    };
    return error.TestUnexpectedResult;
}

pub fn exerciseCritical(
    allocator: std.mem.Allocator,
    io: std.Io,
    category: migrations.CriticalCategory,
) !void {
    if (category == .discovery_failure) {
        try exercisePositiveSweep(allocator, io);
        try exerciseMultiMigrationSweep(allocator, io);
        try exerciseValidationSweep(allocator, io);
    }
    return switch (category) {
        .discovery_failure => expectPublicError(error.DiscoveryFailure, discoveryFailure(allocator, io, .{ .owner = "p0", .path = "missing/p0" })),
        .missing_manifest => expectPublicError(error.MissingManifest, fixtureFailure(allocator, io, category)),
        .missing_script => expectPublicError(error.MissingScript, fixtureFailure(allocator, io, category)),
        .malformed_manifest => expectPublicError(error.MalformedManifest, fixtureFailure(allocator, io, category)),
        .unknown_descriptor_field => expectPublicError(error.UnknownDescriptorField, fixtureFailure(allocator, io, category)),
        .invalid_uuid => expectPublicError(error.InvalidUuid, fixtureFailure(allocator, io, category)),
        .owner_mismatch => expectPublicError(error.OwnerMismatch, fixtureFailure(allocator, io, category)),
        .directory_mismatch => expectPublicError(error.DirectoryMismatch, fixtureFailure(allocator, io, category)),
        .path_traversal => expectPublicError(error.PathTraversal, discoveryFailure(allocator, io, .{ .owner = "p0", .path = "migrations/../p0" })),
        .symlink_escape => expectPublicError(error.SymlinkEscape, fixtureFailure(allocator, io, category)),
        .noncanonical_dependencies => expectPublicError(error.NoncanonicalDependencies, fixtureFailure(allocator, io, category)),
        .script_digest_mismatch => expectPublicError(error.ScriptDigestMismatch, fixtureFailure(allocator, io, category)),
        .descriptor_digest_mismatch => expectPublicError(error.DescriptorDigestMismatch, fixtureFailure(allocator, io, category)),
        .duplicate_migration_id => expectPublicError(error.DuplicateMigrationId, graphFailure(allocator, category)),
        .duplicate_descriptor_path => expectPublicError(error.DuplicateDescriptorPath, graphFailure(allocator, category)),
        .missing_dependency => expectPublicError(error.MissingDependency, graphFailure(allocator, category)),
        .self_dependency => expectPublicError(error.SelfDependency, graphFailure(allocator, category)),
        .dependency_cycle => expectPublicError(error.DependencyCycle, graphFailure(allocator, category)),
        .graph_capacity_exceeded => expectPublicError(error.GraphCapacityExceeded, graphFailure(allocator, category)),
        .corrupt_applied_history => expectPublicError(error.CorruptAppliedHistory, historyFailure(allocator, io, category)),
        .duplicate_applied_history => expectPublicError(error.DuplicateAppliedHistory, historyFailure(allocator, io, category)),
        .applied_id_drift => expectPublicError(error.AppliedIdDrift, historyFailure(allocator, io, category)),
        .applied_owner_drift => expectPublicError(error.AppliedOwnerDrift, historyFailure(allocator, io, category)),
        .applied_descriptor_drift => expectPublicError(error.AppliedDescriptorDrift, historyFailure(allocator, io, category)),
        .applied_script_drift => expectPublicError(error.AppliedScriptDrift, historyFailure(allocator, io, category)),
        .ddl_failure => ddlFailure(allocator, io, false),
        .later_migration_blocked => ddlFailure(allocator, io, true),
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
        .allocation_failure_cleanup => allocationFailureScenario(allocator, io),
    };
}

fn expectPublicError(expected: anyerror, result: anytype) !void {
    _ = result catch |observed| {
        try std.testing.expectEqual(expected, observed);
        return;
    };
    return error.TestUnexpectedResult;
}

fn exercisePositiveSweep(allocator: std.mem.Allocator, io: std.Io) !void {
    var discovered = try migrations.discover(
        allocator,
        io,
        &.{.{ .owner = "p0", .path = "migrations/p0" }},
    );
    defer discovered.deinit();
    var ordered = try migrations.plan(allocator, discovered.descriptors);
    defer ordered.deinit();
    const canonical = try migrations.canonicalProjection(
        allocator,
        discovered.descriptors[0].id,
        discovered.descriptors[0].owner,
        discovered.descriptors[0].name,
        @ptrCast(discovered.descriptors[0].depends_on),
        discovered.descriptors[0].script_path,
        discovered.descriptors[0].script_digest,
    );
    defer allocator.free(canonical);
    const escaped = try migrations.canonicalProjection(
        allocator,
        discovered.descriptors[0].id,
        "p0",
        "quote\"slash\\coverage",
        &.{
            "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e51",
            "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e50",
        },
        "up.sql",
        discovered.descriptors[0].script_digest,
    );
    defer allocator.free(escaped);
    const a = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e40";
    const b = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e41";
    const c = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e42";
    const d = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e43";
    const graph = [_]migrations.Descriptor{
        borrowedDescriptor(d, &.{ b, c }, "p0/d/manifest.json"),
        borrowedDescriptor(c, &.{a}, "p0/c/manifest.json"),
        borrowedDescriptor(a, &.{}, "p0/a/manifest.json"),
        borrowedDescriptor(b, &.{a}, "p0/b/manifest.json"),
    };
    var graph_plan = try migrations.plan(allocator, &graph);
    defer graph_plan.deinit();
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try std.fmt.allocPrint(
        allocator,
        ".zig-cache/tmp/{s}/wp07-sweep.shovel",
        .{tmp.sub_path},
    );
    defer allocator.free(database_path);
    var store = try migrations.testing.openStoreWithFaults(allocator, io, database_path, .{});
    defer store.shutdown() catch {};
    const first = try migrations.run(
        allocator,
        io,
        &store,
        &.{.{ .owner = "p0", .path = "migrations/p0" }},
        "2026-07-21T12:34:56.789Z",
    );
    try std.testing.expect(first.isReady());
    const second = try migrations.run(
        allocator,
        io,
        &store,
        &.{.{ .owner = "p0", .path = "migrations/p0" }},
        "2026-07-21T12:34:56.789Z",
    );
    try std.testing.expect(second.isReady());
}

fn exerciseMultiMigrationSweep(allocator: std.mem.Allocator, io: std.Io) !void {
    const a = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e50";
    const b = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e51";
    const c = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e52";
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const root_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/p0", .{tmp.sub_path});
    defer allocator.free(root_path);
    try writeMigration(allocator, io, root_path, bootstrap_id, "bootstrap_migration_history", &.{}, "[]", bootstrap_script);
    try writeMigration(
        allocator,
        io,
        root_path,
        a,
        "create_a",
        &.{bootstrap_id},
        "[\"018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f\"]",
        "CREATE TABLE migration_a (id TEXT);\n",
    );
    try writeMigration(
        allocator,
        io,
        root_path,
        b,
        "create_b",
        &.{bootstrap_id},
        "[\"018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f\"]",
        "CREATE TABLE migration_b (id TEXT);\n",
    );
    try writeMigration(
        allocator,
        io,
        root_path,
        c,
        "create_c",
        &.{ a, b },
        "[\"018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e50\",\"018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e51\"]",
        "CREATE TABLE migration_c (id TEXT);\n",
    );
    var discovered = try migrations.discover(
        allocator,
        io,
        &.{.{ .owner = "p0", .path = root_path }},
    );
    defer discovered.deinit();
    try std.testing.expectEqual(@as(usize, 4), discovered.descriptors.len);
    var ordered = try migrations.plan(allocator, discovered.descriptors);
    defer ordered.deinit();
    try std.testing.expectEqual(@as(usize, 4), ordered.order.len);

    const database_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/wp07-multi.shovel", .{tmp.sub_path});
    defer allocator.free(database_path);
    var store = try migrations.testing.openStoreWithFaults(allocator, io, database_path, .{});
    defer store.shutdown() catch {};
    const first = try migrations.run(
        allocator,
        io,
        &store,
        &.{.{ .owner = "p0", .path = root_path }},
        "2026-07-21T12:34:56.789Z",
    );
    try std.testing.expect(first.isReady());
    try std.testing.expectEqual(@as(usize, 4), first.applied_count);
    const second = try migrations.run(
        allocator,
        io,
        &store,
        &.{.{ .owner = "p0", .path = root_path }},
        "2026-07-21T12:34:56.789Z",
    );
    try std.testing.expect(second.isReady());
    try std.testing.expectEqual(@as(usize, 4), second.already_applied_count);
}

fn expectDiscoverError(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: migrations.OwnerRoot,
    expected: anyerror,
) !void {
    var discovered = migrations.discover(allocator, io, &.{root}) catch |err| {
        try std.testing.expectEqual(expected, err);
        return;
    };
    discovered.deinit();
    return error.TestUnexpectedResult;
}

fn expectManifestError(
    allocator: std.mem.Allocator,
    io: std.Io,
    manifest: []const u8,
    script: ?[]const u8,
    script_is_directory: bool,
    expected: anyerror,
) !void {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const root_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/p0", .{tmp.sub_path});
    defer allocator.free(root_path);
    const migration_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ root_path, bootstrap_id });
    defer allocator.free(migration_path);
    try std.Io.Dir.createDirPath(.cwd(), io, migration_path);
    const manifest_path = try std.fmt.allocPrint(allocator, "{s}/manifest.json", .{migration_path});
    defer allocator.free(manifest_path);
    try std.Io.Dir.writeFile(.cwd(), io, .{ .sub_path = manifest_path, .data = manifest });
    const script_path = try std.fmt.allocPrint(allocator, "{s}/up.sql", .{migration_path});
    defer allocator.free(script_path);
    if (script_is_directory) {
        try std.Io.Dir.createDirPath(.cwd(), io, script_path);
    } else if (script) |bytes| {
        try std.Io.Dir.writeFile(.cwd(), io, .{ .sub_path = script_path, .data = bytes });
    }
    try expectDiscoverError(allocator, io, .{ .owner = "p0", .path = root_path }, expected);
}

fn exerciseValidationSweep(allocator: std.mem.Allocator, io: std.Io) !void {
    try expectDiscoverError(allocator, io, .{ .owner = "", .path = "migrations/p0" }, error.OwnerMismatch);
    try expectDiscoverError(allocator, io, .{ .owner = "q0", .path = "migrations/p0" }, error.OwnerMismatch);
    try expectDiscoverError(allocator, io, .{ .owner = "p9", .path = "migrations/p0" }, error.OwnerMismatch);
    try expectDiscoverError(allocator, io, .{ .owner = "p00", .path = "migrations/p0" }, error.OwnerMismatch);
    try expectDiscoverError(allocator, io, .{ .owner = "p0", .path = "/tmp" }, error.PathTraversal);

    const valid_manifest =
        "{\"id\":\"018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f\",\"owner\":\"p0\",\"name\":\"bootstrap_migration_history\",\"depends_on\":[],\"script_path\":\"up.sql\",\"script_digest\":\"sha256:68dff6daa265a0c0c6d603994438c43a0af3228fff72e677d9dcd0cd60b1fbd3\",\"descriptor_digest\":\"sha256:0b5af56a66a73c1f0f96b76ad4307a6e3a76f3cd34cb0ba71197a5e90d4e7877\"}";
    try expectManifestError(allocator, io, "[]", null, false, error.MalformedManifest);
    try expectManifestError(
        allocator,
        io,
        "{\"id\":\"018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f\",\"owner\":\"p0\",\"name\":\"\",\"depends_on\":[],\"script_path\":\"up.sql\",\"script_digest\":\"sha256:68dff6daa265a0c0c6d603994438c43a0af3228fff72e677d9dcd0cd60b1fbd3\",\"descriptor_digest\":\"sha256:0b5af56a66a73c1f0f96b76ad4307a6e3a76f3cd34cb0ba71197a5e90d4e7877\"}",
        null,
        false,
        error.MalformedManifest,
    );
    try expectManifestError(
        allocator,
        io,
        "{\"id\":\"018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f\",\"owner\":\"p0\",\"name\":\"Upper\",\"depends_on\":[],\"script_path\":\"up.sql\",\"script_digest\":\"sha256:68dff6daa265a0c0c6d603994438c43a0af3228fff72e677d9dcd0cd60b1fbd3\",\"descriptor_digest\":\"sha256:0b5af56a66a73c1f0f96b76ad4307a6e3a76f3cd34cb0ba71197a5e90d4e7877\"}",
        null,
        false,
        error.MalformedManifest,
    );
    try expectManifestError(
        allocator,
        io,
        "{\"id\":\"018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f\",\"owner\":\"p0\",\"name\":\"bad-name\",\"depends_on\":[],\"script_path\":\"up.sql\",\"script_digest\":\"sha256:68dff6daa265a0c0c6d603994438c43a0af3228fff72e677d9dcd60b1fbd3\",\"descriptor_digest\":\"sha256:0b5af56a66a73c1f0f96b76ad4307a6e3a76f3cd34cb0ba71197a5e90d4e7877\"}",
        null,
        false,
        error.MalformedManifest,
    );
    try expectManifestError(
        allocator,
        io,
        "{\"id\":\"018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f\",\"owner\":\"p0\",\"name\":\"bootstrap_migration_history\",\"depends_on\":[],\"script_path\":\"../up.sql\",\"script_digest\":\"sha256:68dff6daa265a0c0c6d603994438c43a0af3228fff72e677d9dcd60b1fbd3\",\"descriptor_digest\":\"sha256:0b5af56a66a73c1f0f96b76ad4307a6e3a76f3cd34cb0ba71197a5e90d4e7877\"}",
        null,
        false,
        error.PathTraversal,
    );
    try expectManifestError(
        allocator,
        io,
        "{\"id\":\"018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f\",\"owner\":\"p0\",\"name\":\"bootstrap_migration_history\",\"depends_on\":[],\"script_path\":\"up.sql\",\"script_digest\":\"bad\",\"descriptor_digest\":\"sha256:0b5af56a66a73c1f0f96b76ad4307a6e3a76f3cd34cb0ba71197a5e90d4e7877\"}",
        null,
        false,
        error.ScriptDigestMismatch,
    );
    try expectManifestError(
        allocator,
        io,
        "{\"id\":\"018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f\",\"owner\":\"p0\",\"name\":\"bootstrap_migration_history\",\"depends_on\":[],\"script_path\":\"up.sql\",\"script_digest\":\"sha256:68dff6daa265a0c0c6d603994438c43a0af3228fff72e677d9dcd0cd60b1fbd3\",\"descriptor_digest\":\"bad\"}",
        null,
        false,
        error.DescriptorDigestMismatch,
    );
    try expectManifestError(
        allocator,
        io,
        "{\"id\":\"018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f\",\"owner\":\"p0\",\"name\":\"bootstrap_migration_history\",\"depends_on\":[\"not-a-uuid\"],\"script_path\":\"up.sql\",\"script_digest\":\"sha256:68dff6daa265a0c0c6d603994438c43a0af3228fff72e677d9dcd60b1fbd3\",\"descriptor_digest\":\"sha256:0b5af56a66a73c1f0f96b76ad4307a6e3a76f3cd34cb0ba71197a5e90d4e7877\"}",
        null,
        false,
        error.NoncanonicalDependencies,
    );
    try expectManifestError(allocator, io, valid_manifest, null, true, error.MissingScript);

    const control_projection = migrations.canonicalProjection(
        allocator,
        bootstrap_id,
        "p0",
        "bad\x01name",
        &.{},
        "up.sql",
        bootstrap_script_digest,
    );
    try std.testing.expectError(error.AllocationFailureCleanup, control_projection);

    const ready_base = migrations.Readiness{
        .status = .ready,
        .discovered_count = 1,
        .applied_count = 1,
        .already_applied_count = 0,
        .application_complete = true,
        .checkpoint_complete = true,
        .directory_sync_complete = true,
        .durable_reopen_complete = true,
    };
    var readiness = ready_base;
    readiness.status = .durability_unconfirmed;
    try std.testing.expect(!readiness.isReady());
    readiness = ready_base;
    readiness.application_complete = false;
    try std.testing.expect(!readiness.isReady());
    readiness = ready_base;
    readiness.checkpoint_complete = false;
    try std.testing.expect(!readiness.isReady());
    readiness = ready_base;
    readiness.directory_sync_complete = false;
    try std.testing.expect(!readiness.isReady());
    readiness = ready_base;
    readiness.durable_reopen_complete = false;
    try std.testing.expect(!readiness.isReady());

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/wp07-invalid-time.shovel", .{tmp.sub_path});
    defer allocator.free(database_path);
    var store = try migrations.testing.openStoreWithFaults(allocator, io, database_path, .{});
    defer store.shutdown() catch {};
    try std.testing.expectError(
        error.CorruptAppliedHistory,
        migrations.run(
            allocator,
            io,
            &store,
            &.{.{ .owner = "p0", .path = "migrations/p0" }},
            "not-an-instant",
        ),
    );
    try exerciseHistoryShapeSweep(allocator, io);
    try exerciseRemainingBoundarySweep(allocator, io);
}

fn exerciseRemainingBoundarySweep(allocator: std.mem.Allocator, io: std.Io) !void {
    var names_tmp = std.testing.tmpDir(.{});
    defer names_tmp.cleanup();
    const root_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/p0", .{names_tmp.sub_path});
    defer allocator.free(root_path);
    const wrong_uuid_shapes = [_][]const u8{
        "018f6f10x7b7a-7c2d-8e65-0f7b1c2d3e4f",
        "018f6f10-7b7ax7c2d-8e65-0f7b1c2d3e4f",
        "018f6f10-7b7a-7c2dx8e65-0f7b1c2d3e4f",
        "018f6f10-7b7a-7c2d-8e65x0f7b1c2d3e4f",
    };
    for (wrong_uuid_shapes) |name| {
        const path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ root_path, name });
        defer allocator.free(path);
        try std.Io.Dir.createDirPath(.cwd(), io, path);
    }
    var empty = try migrations.discover(
        allocator,
        io,
        &.{.{ .owner = "p0", .path = root_path }},
    );
    defer empty.deinit();
    try std.testing.expectEqual(@as(usize, 0), empty.descriptors.len);

    const fault_cases = [_]migrations.testing.Faults{
        .{ .checkpoint = true },
        .{ .directory_sync = true },
        .{ .unsupported_directory_sync = true },
    };
    for (fault_cases) |faults| {
        var tmp = std.testing.tmpDir(.{});
        defer tmp.cleanup();
        const database_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/wp07-retry.shovel", .{tmp.sub_path});
        defer allocator.free(database_path);
        var store = try migrations.testing.openStoreWithFaults(allocator, io, database_path, faults);
        defer store.shutdown() catch {};
        const initial = try migrations.run(
            allocator,
            io,
            &store,
            &.{.{ .owner = "p0", .path = "migrations/p0" }},
            "2026-07-21T12:34:56.789Z",
        );
        try std.testing.expect(!initial.isReady());
        const repeated = try migrations.completeDurability(&store, initial);
        try std.testing.expect(!repeated.isReady());
        migrations.testing.setFaults(&store, .{});
        const completed = try migrations.completeDurability(&store, repeated);
        try std.testing.expect(completed.isReady());
    }

    const short_diagnostic_graph = [_]migrations.Descriptor{
        borrowedDescriptor(bootstrap_id, &.{"short"}, "p0/short/manifest.json"),
    };
    var diagnostic = migrations.PlanDiagnostic{};
    try std.testing.expectError(
        error.MissingDependency,
        migrations.planWithDiagnostic(allocator, &short_diagnostic_graph, &diagnostic),
    );
    try std.testing.expectEqual(@as(usize, 0), diagnostic.ids_len);

    const cycle_ids = [_][]const u8{
        "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e40",
        "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e41",
        "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e42",
        "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e43",
        "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e44",
        "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e45",
        "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e46",
        "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e47",
        "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e48",
        "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e49",
        "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4a",
        "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4b",
        "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4c",
        "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4d",
        "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4e",
        "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f",
        "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e50",
    };
    var cycle_dependencies: [cycle_ids.len][1][]const u8 = undefined;
    var saturated_diagnostic_graph: [cycle_ids.len]migrations.Descriptor = undefined;
    for (cycle_ids, 0..) |id, index| {
        cycle_dependencies[index][0] = cycle_ids[(index + 1) % cycle_ids.len];
        saturated_diagnostic_graph[index] = borrowedDescriptor(
            id,
            cycle_dependencies[index][0..],
            id,
        );
    }
    var saturated = migrations.PlanDiagnostic{};
    try std.testing.expectError(
        error.DependencyCycle,
        migrations.planWithDiagnostic(allocator, &saturated_diagnostic_graph, &saturated),
    );
    try std.testing.expectEqual(@as(usize, 16), saturated.ids_len);
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
    try std.testing.expect(evidence.initial.application_complete);
    try std.testing.expect(!evidence.initial.directory_sync_complete);
    try std.testing.expect(evidence.initial.durable_reopen_complete);
    switch (category) {
        .checkpoint_failure => {
            try std.testing.expectEqual(migrations.CriticalCategory.checkpoint_failure, evidence.initial.category.?);
            try std.testing.expect(!evidence.initial.checkpoint_complete);
        },
        .directory_sync_failure => {
            try std.testing.expectEqual(migrations.CriticalCategory.directory_sync_failure, evidence.initial.category.?);
            try std.testing.expect(evidence.initial.checkpoint_complete);
        },
        .unsupported_directory_sync => {
            try std.testing.expectEqual(migrations.CriticalCategory.unsupported_directory_sync, evidence.initial.category.?);
            try std.testing.expect(evidence.initial.checkpoint_complete);
        },
        .durability_unconfirmed => try std.testing.expect(!evidence.initial.isReady()),
        .committed_not_durable => {
            try std.testing.expectEqual(migrations.CriticalCategory.checkpoint_failure, evidence.initial.category.?);
            try std.testing.expect(!evidence.initial.checkpoint_complete);
            try std.testing.expect(!evidence.initial.directory_sync_complete);
        },
        .checkpointed_not_durable => {
            try std.testing.expectEqual(migrations.CriticalCategory.directory_sync_failure, evidence.initial.category.?);
            try std.testing.expect(evidence.initial.checkpoint_complete);
            try std.testing.expect(!evidence.initial.directory_sync_complete);
        },
        else => return error.TestUnexpectedResult,
    }
    try std.testing.expect(!evidence.completed.isReady());
    try std.testing.expectEqual(evidence.initial.applied_count, evidence.completed.applied_count);
    try std.testing.expectEqual(@as(usize, 1), evidence.application_calls);
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
    if (category == .symlink_escape) {
        try std.Io.Dir.createDirPath(.cwd(), io, root_path);
        const link_path = try std.fmt.allocPrint(allocator, "{s}/escape", .{root_path});
        defer allocator.free(link_path);
        try std.Io.Dir.symLink(.cwd(), io, "..", link_path, .{});
        return discoveryFailure(allocator, io, .{ .owner = "p0", .path = root_path });
    }
    const invalid_id = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4F";
    const directory_id = if (category == .invalid_uuid) invalid_id else bootstrap_id;
    const migration_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ root_path, directory_id });
    defer allocator.free(migration_path);
    try std.Io.Dir.createDirPath(.cwd(), io, migration_path);
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
        else => return error.TestUnexpectedResult,
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
            &.{.{ .owner = "p0", .path = "migrations/p0" }},
        ) catch |err| {
            if (err == error.AllocationFailureCleanup) observed = true;
            continue;
        };
        discovered.deinit();
    }

    const a = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e50";
    const b = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e51";
    const c = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e52";
    const d = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e53";
    const graph = [_]migrations.Descriptor{
        borrowedDescriptor(d, &.{ b, c }, "p0/d/manifest.json"),
        borrowedDescriptor(c, &.{a}, "p0/c/manifest.json"),
        borrowedDescriptor(a, &.{}, "p0/a/manifest.json"),
        borrowedDescriptor(b, &.{a}, "p0/b/manifest.json"),
    };
    const cycle = [_]migrations.Descriptor{
        borrowedDescriptor(a, &.{b}, "p0/a/manifest.json"),
        borrowedDescriptor(b, &.{a}, "p0/b/manifest.json"),
    };
    for (0..32) |failure_index| {
        var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = failure_index });
        var planned = migrations.plan(failing.allocator(), &graph) catch |err| {
            if (err == error.AllocationFailureCleanup) observed = true;
            continue;
        };
        planned.deinit();
    }
    for (0..32) |failure_index| {
        var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = failure_index });
        var diagnostic = migrations.PlanDiagnostic{};
        var planned = migrations.planWithDiagnostic(failing.allocator(), &cycle, &diagnostic) catch |err| {
            if (err == error.AllocationFailureCleanup) observed = true;
            continue;
        };
        planned.deinit();
    }
    for (0..64) |failure_index| {
        var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = failure_index });
        const projection = migrations.canonicalProjection(
            failing.allocator(),
            a,
            "p0",
            "quote\"slash\\allocation",
            &.{ c, b },
            "up.sql",
            bootstrap_script_digest,
        ) catch |err| {
            if (err == error.AllocationFailureCleanup) observed = true;
            continue;
        };
        failing.allocator().free(projection);
    }

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const root_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/p0", .{tmp.sub_path});
    defer allocator.free(root_path);
    try writeMigration(allocator, io, root_path, bootstrap_id, "bootstrap_migration_history", &.{}, "[]", bootstrap_script);
    try writeMigration(
        allocator,
        io,
        root_path,
        a,
        "create_a",
        &.{bootstrap_id},
        "[\"018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f\"]",
        "CREATE TABLE allocation_a (id TEXT);\n",
    );
    try writeMigration(
        allocator,
        io,
        root_path,
        b,
        "create_b",
        &.{bootstrap_id},
        "[\"018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f\"]",
        "CREATE TABLE allocation_b (id TEXT);\n",
    );
    try writeMigration(
        allocator,
        io,
        root_path,
        c,
        "create_c",
        &.{ a, b },
        "[\"018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e50\",\"018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e51\"]",
        "CREATE TABLE allocation_c (id TEXT);\n",
    );
    for (0..192) |failure_index| {
        var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = failure_index });
        var discovered = migrations.discover(
            failing.allocator(),
            io,
            &.{.{ .owner = "p0", .path = root_path }},
        ) catch |err| {
            if (err == error.AllocationFailureCleanup) observed = true;
            continue;
        };
        discovered.deinit();
    }

    const database_path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/wp07-allocation.shovel", .{tmp.sub_path});
    defer allocator.free(database_path);
    var store = try migrations.testing.openStoreWithFaults(allocator, io, database_path, .{});
    defer store.shutdown() catch {};
    _ = try migrations.run(
        allocator,
        io,
        &store,
        &.{.{ .owner = "p0", .path = root_path }},
        "2026-07-21T12:34:56.789Z",
    );
    try std.testing.expect(observed);
    for (0..192) |failure_index| {
        var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = failure_index });
        const discard_before = migrations.testing.discardCount(&store);
        const reopen_before = migrations.testing.reopenCount(&store);
        _ = migrations.run(
            failing.allocator(),
            io,
            &store,
            &.{.{ .owner = "p0", .path = root_path }},
            "2026-07-21T12:34:56.789Z",
        ) catch |err| {
            try std.testing.expect(failing.has_induced_failure);
            try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
            try std.testing.expectEqual(failing.allocations, failing.deallocations);
            if (migrations.testing.discardCount(&store) == discard_before + 1) {
                try std.testing.expectEqual(reopen_before + 1, migrations.testing.reopenCount(&store));
                try std.testing.expectEqual(.ready, store.state());
                return err;
            }
            continue;
        };
    }
    return error.TestUnexpectedResult;
}
