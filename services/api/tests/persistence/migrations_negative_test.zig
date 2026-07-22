const std = @import("std");
const migrations = @import("migrations");
const scenarios = @import("migrations_integration_test.zig");

test "migration negative matrix executes every stable failure category" {
    const cases = [_]migrations.CriticalCategory{
        .discovery_failure,
        .missing_manifest,
        .missing_script,
        .malformed_manifest,
        .unknown_descriptor_field,
        .invalid_uuid,
        .owner_mismatch,
        .directory_mismatch,
        .path_traversal,
        .symlink_escape,
        .noncanonical_dependencies,
        .script_digest_mismatch,
        .descriptor_digest_mismatch,
        .duplicate_migration_id,
        .duplicate_descriptor_path,
        .missing_dependency,
        .self_dependency,
        .dependency_cycle,
        .graph_capacity_exceeded,
        .corrupt_applied_history,
        .duplicate_applied_history,
        .applied_id_drift,
        .applied_owner_drift,
        .applied_descriptor_drift,
        .applied_script_drift,
        .ddl_failure,
        .checkpoint_failure,
        .directory_sync_failure,
        .reopen_failure,
        .recovery_quarantine,
        .durability_unconfirmed,
        .unsupported_directory_sync,
        .committed_not_durable,
        .checkpointed_not_durable,
        .later_migration_blocked,
        .allocation_failure_cleanup,
    };

    var executed: usize = 0;
    for (cases) |case| {
        try scenarios.exerciseCritical(std.testing.allocator, std.testing.io, case);
        executed += 1;
    }
    try std.testing.expectEqual(cases.len, executed);
}
