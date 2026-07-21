const std = @import("std");

pub const minimum_percent: usize = 90;
pub const minimum_production_sites: usize = 20;
pub const critical_test_prefix = "critical branch: ";

pub const CriticalBranch = enum(u8) {
    canonicalization_failure,
    lease_acquire_failure,
    lease_conflict,
    engine_open_failure,
    partial_open_cleanup,
    transaction_begin_failure,
    callback_failure,
    rollback_failure,
    commit_failure,
    checkpoint_failure,
    directory_open_failure,
    directory_sync_failure,
    directory_close_failure,
    uncertain_transition,
    quarantined_refusal,
    dirty_discard_failure,
    reopen_failure,
    recovery_quarantine,
    unsupported_directory_sync,
    shutdown_failure,
};

pub const critical_branch_names = branchNames();
pub const critical_branch_count = critical_branch_names.len;

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

test "persistence measurement is non-vacuous and thresholded" {
    const required = requiredBranchBits();
    try std.testing.expectError(CoverageError.IncompleteProductionInstrumentation, validateMeasurement(.{
        .seen_sites = 19,
        .total_sites = 19,
        .hit_branch_bits = required,
        .required_branch_bits = required,
    }));
    try std.testing.expectError(CoverageError.BelowThreshold, validateMeasurement(.{
        .seen_sites = 89,
        .total_sites = 100,
        .hit_branch_bits = required,
        .required_branch_bits = required,
    }));
}
