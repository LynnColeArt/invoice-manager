const std = @import("std");
pub const contract = @import("migration_coverage_contract");

var hit_bits: std.atomic.Value(u64) = .init(0);

pub fn hit(comptime branch: contract.CriticalBranch) void {
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
    return contract.requiredBranchBits();
}
