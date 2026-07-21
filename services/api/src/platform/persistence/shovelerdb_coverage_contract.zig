const std = @import("std");

pub const minimum_percent: usize = 90;
pub const critical_test_prefix = "critical branch: ";

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

pub const critical_branch_names = branchNames();
pub const critical_branch_count = critical_branch_names.len;
pub const minimum_production_sites = critical_branch_count;

pub const Measurement = struct {
    seen_sites: usize,
    total_sites: usize,
    hit_branch_bits: u64,
    required_branch_bits: u64,
};

pub const CoverageError = error{
    MissingMeasurement,
    InvalidMeasurement,
    IncompleteProductionInstrumentation,
    BelowThreshold,
    MissingCriticalBranch,
};

pub fn requiredBranchBits() u64 {
    comptime std.debug.assert(critical_branch_count > 0 and critical_branch_count < 64);
    return (@as(u64, 1) << @intCast(critical_branch_count)) - 1;
}

pub fn validateMeasurement(measurement: Measurement) CoverageError!void {
    if (measurement.total_sites == 0) return CoverageError.MissingMeasurement;
    if (measurement.seen_sites > measurement.total_sites or
        measurement.required_branch_bits != requiredBranchBits())
    {
        return CoverageError.InvalidMeasurement;
    }
    if (measurement.total_sites < minimum_production_sites) {
        return CoverageError.IncompleteProductionInstrumentation;
    }
    if (@as(u128, measurement.seen_sites) * 100 <
        @as(u128, measurement.total_sites) * minimum_percent)
    {
        return CoverageError.BelowThreshold;
    }
    if (measurement.hit_branch_bits & measurement.required_branch_bits != measurement.required_branch_bits) {
        return CoverageError.MissingCriticalBranch;
    }
}

pub fn branchIndexFromTestName(test_name: []const u8) ?usize {
    for (critical_branch_names, 0..) |branch_name, index| {
        if (!std.mem.endsWith(u8, test_name, branch_name)) continue;
        const prefix = test_name[0 .. test_name.len - branch_name.len];
        if (std.mem.endsWith(u8, prefix, critical_test_prefix)) return index;
    }
    return null;
}

fn branchNames() [std.meta.fields(CriticalBranch).len][]const u8 {
    const fields = std.meta.fields(CriticalBranch);
    var names: [fields.len][]const u8 = undefined;
    inline for (fields, 0..) |field, index| names[index] = field.name;
    return names;
}

test "measurement rejects missing low incomplete critical and fabricated evidence" {
    const required = requiredBranchBits();
    try std.testing.expectError(CoverageError.MissingMeasurement, validateMeasurement(.{
        .seen_sites = 0,
        .total_sites = 0,
        .hit_branch_bits = required,
        .required_branch_bits = required,
    }));
    try std.testing.expectError(CoverageError.InvalidMeasurement, validateMeasurement(.{
        .seen_sites = 101,
        .total_sites = 100,
        .hit_branch_bits = required,
        .required_branch_bits = required,
    }));
    try std.testing.expectError(CoverageError.IncompleteProductionInstrumentation, validateMeasurement(.{
        .seen_sites = 1,
        .total_sites = 1,
        .hit_branch_bits = required,
        .required_branch_bits = required,
    }));
    try std.testing.expectError(CoverageError.BelowThreshold, validateMeasurement(.{
        .seen_sites = 89,
        .total_sites = 100,
        .hit_branch_bits = required,
        .required_branch_bits = required,
    }));
    try std.testing.expectError(CoverageError.MissingCriticalBranch, validateMeasurement(.{
        .seen_sites = 90,
        .total_sites = 100,
        .hit_branch_bits = required & ~@as(u64, 1),
        .required_branch_bits = required,
    }));
    try std.testing.expectError(CoverageError.InvalidMeasurement, validateMeasurement(.{
        .seen_sites = 90,
        .total_sites = 100,
        .hit_branch_bits = required,
        .required_branch_bits = required & ~@as(u64, 1),
    }));
}

test "measurement accepts complete measured evidence at threshold" {
    try validateMeasurement(.{
        .seen_sites = 90,
        .total_sites = 100,
        .hit_branch_bits = requiredBranchBits(),
        .required_branch_bits = requiredBranchBits(),
    });
}

test "critical test names map only by exact suffix contract" {
    try std.testing.expectEqual(@as(?usize, 0), branchIndexFromTestName(
        "migrations_coverage_test.test.critical branch: discovery_failure",
    ));
    try std.testing.expectEqual(@as(?usize, null), branchIndexFromTestName(
        "migrations_coverage_test.test.discovery_failure",
    ));
    try std.testing.expectEqual(@as(?usize, null), branchIndexFromTestName(
        "migrations_coverage_test.test.critical branch: discovery_failure_extra",
    ));
}
