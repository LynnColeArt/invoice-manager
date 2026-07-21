const std = @import("std");

pub const CriticalBranch = enum(u8) {
    discovery_failure,
    missing_manifest,
    missing_script,
    malformed_manifest,
    unknown_descriptor_field,
    invalid_uuid,
    owner_mismatch,
    directory_mismatch,
    path_traversal,
    symlink_escape,
    noncanonical_dependencies,
    script_digest_mismatch,
    descriptor_digest_mismatch,
    duplicate_migration_id,
    duplicate_descriptor_path,
    missing_dependency,
    self_dependency,
    dependency_cycle,
    graph_capacity_exceeded,
    corrupt_applied_history,
    duplicate_applied_history,
    applied_id_drift,
    applied_owner_drift,
    applied_descriptor_drift,
    applied_script_drift,
    ddl_failure,
    checkpoint_failure,
    directory_sync_failure,
    reopen_failure,
    recovery_quarantine,
    durability_unconfirmed,
    unsupported_directory_sync,
    committed_not_durable,
    checkpointed_not_durable,
    later_migration_blocked,
    allocation_failure_cleanup,
};

var hit_bits: std.atomic.Value(u64) = .init(0);

pub fn hit(comptime branch: CriticalBranch) void {
    @disableInstrumentation();
    _ = hit_bits.fetchOr(@as(u64, 1) << @intFromEnum(branch), .monotonic);
}

export fn invoice_manager_migration_coverage_reset() void {
    @disableInstrumentation();
    hit_bits.store(0, .monotonic);
}

export fn invoice_manager_migration_coverage_hit_bits() u64 {
    @disableInstrumentation();
    return hit_bits.load(.monotonic);
}

export fn invoice_manager_migration_coverage_required_bits() u64 {
    @disableInstrumentation();
    return (@as(u64, 1) << @typeInfo(CriticalBranch).@"enum".fields.len) - 1;
}
