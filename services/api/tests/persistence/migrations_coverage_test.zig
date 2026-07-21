const std = @import("std");
const migrations = @import("migrations");

test "migration production declarations are analyzed" {
    std.testing.refAllDecls(migrations);
}

test "critical branch: discovery_failure" {
    try std.testing.expectError(migrations.expectedError(.discovery_failure), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .discovery_failure));
}

test "critical branch: missing_manifest" {
    try std.testing.expectError(migrations.expectedError(.missing_manifest), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .missing_manifest));
}

test "critical branch: missing_script" {
    try std.testing.expectError(migrations.expectedError(.missing_script), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .missing_script));
}

test "critical branch: malformed_manifest" {
    try std.testing.expectError(migrations.expectedError(.malformed_manifest), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .malformed_manifest));
}

test "critical branch: unknown_descriptor_field" {
    try std.testing.expectError(migrations.expectedError(.unknown_descriptor_field), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .unknown_descriptor_field));
}

test "critical branch: invalid_uuid" {
    try std.testing.expectError(migrations.expectedError(.invalid_uuid), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .invalid_uuid));
}

test "critical branch: owner_mismatch" {
    try std.testing.expectError(migrations.expectedError(.owner_mismatch), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .owner_mismatch));
}

test "critical branch: directory_mismatch" {
    try std.testing.expectError(migrations.expectedError(.directory_mismatch), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .directory_mismatch));
}

test "critical branch: path_traversal" {
    try std.testing.expectError(migrations.expectedError(.path_traversal), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .path_traversal));
}

test "critical branch: symlink_escape" {
    try std.testing.expectError(migrations.expectedError(.symlink_escape), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .symlink_escape));
}

test "critical branch: noncanonical_dependencies" {
    try std.testing.expectError(migrations.expectedError(.noncanonical_dependencies), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .noncanonical_dependencies));
}

test "critical branch: script_digest_mismatch" {
    try std.testing.expectError(migrations.expectedError(.script_digest_mismatch), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .script_digest_mismatch));
}

test "critical branch: descriptor_digest_mismatch" {
    try std.testing.expectError(migrations.expectedError(.descriptor_digest_mismatch), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .descriptor_digest_mismatch));
}

test "critical branch: duplicate_migration_id" {
    try std.testing.expectError(migrations.expectedError(.duplicate_migration_id), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .duplicate_migration_id));
}

test "critical branch: duplicate_descriptor_path" {
    try std.testing.expectError(migrations.expectedError(.duplicate_descriptor_path), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .duplicate_descriptor_path));
}

test "critical branch: missing_dependency" {
    try std.testing.expectError(migrations.expectedError(.missing_dependency), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .missing_dependency));
}

test "critical branch: self_dependency" {
    try std.testing.expectError(migrations.expectedError(.self_dependency), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .self_dependency));
}

test "critical branch: dependency_cycle" {
    try std.testing.expectError(migrations.expectedError(.dependency_cycle), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .dependency_cycle));
}

test "critical branch: graph_capacity_exceeded" {
    try std.testing.expectError(migrations.expectedError(.graph_capacity_exceeded), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .graph_capacity_exceeded));
}

test "critical branch: corrupt_applied_history" {
    try std.testing.expectError(migrations.expectedError(.corrupt_applied_history), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .corrupt_applied_history));
}

test "critical branch: duplicate_applied_history" {
    try std.testing.expectError(migrations.expectedError(.duplicate_applied_history), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .duplicate_applied_history));
}

test "critical branch: applied_id_drift" {
    try std.testing.expectError(migrations.expectedError(.applied_id_drift), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .applied_id_drift));
}

test "critical branch: applied_owner_drift" {
    try std.testing.expectError(migrations.expectedError(.applied_owner_drift), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .applied_owner_drift));
}

test "critical branch: applied_descriptor_drift" {
    try std.testing.expectError(migrations.expectedError(.applied_descriptor_drift), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .applied_descriptor_drift));
}

test "critical branch: applied_script_drift" {
    try std.testing.expectError(migrations.expectedError(.applied_script_drift), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .applied_script_drift));
}

test "critical branch: ddl_failure" {
    try std.testing.expectError(migrations.expectedError(.ddl_failure), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .ddl_failure));
}

test "critical branch: checkpoint_failure" {
    try std.testing.expectError(migrations.expectedError(.checkpoint_failure), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .checkpoint_failure));
}

test "critical branch: directory_sync_failure" {
    try std.testing.expectError(migrations.expectedError(.directory_sync_failure), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .directory_sync_failure));
}

test "critical branch: reopen_failure" {
    try std.testing.expectError(migrations.expectedError(.reopen_failure), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .reopen_failure));
}

test "critical branch: recovery_quarantine" {
    try std.testing.expectError(migrations.expectedError(.recovery_quarantine), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .recovery_quarantine));
}

test "critical branch: durability_unconfirmed" {
    try std.testing.expectError(migrations.expectedError(.durability_unconfirmed), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .durability_unconfirmed));
}

test "critical branch: unsupported_directory_sync" {
    try std.testing.expectError(migrations.expectedError(.unsupported_directory_sync), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .unsupported_directory_sync));
}

test "critical branch: committed_not_durable" {
    try std.testing.expectError(migrations.expectedError(.committed_not_durable), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .committed_not_durable));
}

test "critical branch: checkpointed_not_durable" {
    try std.testing.expectError(migrations.expectedError(.checkpointed_not_durable), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .checkpointed_not_durable));
}

test "critical branch: later_migration_blocked" {
    try std.testing.expectError(migrations.expectedError(.later_migration_blocked), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .later_migration_blocked));
}

test "critical branch: allocation_failure_cleanup" {
    try std.testing.expectError(migrations.expectedError(.allocation_failure_cleanup), migrations.testing.exerciseCritical(std.testing.allocator, std.testing.io, .allocation_failure_cleanup));
}
