const std = @import("std");
const migrations = @import("migrations");

test "migration integration producer is build-wired" {
    std.testing.refAllDecls(migrations);
}

fn databasePath(allocator: std.mem.Allocator, tmp: *const std.testing.TmpDir) ![]u8 {
    return std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/wp07.shovel", .{tmp.sub_path});
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
        &.{.{ .owner = "p0", .path = "migrations/p0" }},
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
        &.{.{ .owner = "p0", .path = "migrations/p0" }},
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
            migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, case),
        );
    }
}

test "DDL failure discards dirty state reopens durable state and blocks later work" {
    try std.testing.expectError(
        error.DdlFailure,
        migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .ddl_failure),
    );
    try std.testing.expectError(
        error.LaterMigrationBlocked,
        migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .later_migration_blocked),
    );
    try std.testing.expectError(
        error.ReopenFailure,
        migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .reopen_failure),
    );
    try std.testing.expectError(
        error.RecoveryQuarantine,
        migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .recovery_quarantine),
    );
}

test "durability completion retries persistence and never replays migration DDL" {
    const cases = [_]migrations.CriticalCategory{
        .checkpoint_failure,
        .directory_sync_failure,
        .unsupported_directory_sync,
    };
    for (cases) |case| {
        const evidence = try migrations.testing.completeWithoutReplay(
            std.testing.allocator,
            std.testing.io,
            case,
        );
        try std.testing.expectEqual(@as(usize, 1), evidence.application_calls);
        try std.testing.expect(!evidence.initial.isReady());
        try std.testing.expectEqual(migrations.ReadinessStatus.durability_unconfirmed, evidence.initial.status);
        try std.testing.expect(evidence.completed.isReady());
        try std.testing.expectEqual(@as(usize, 1), evidence.application_calls);
    }
}
