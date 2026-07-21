const std = @import("std");

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

var hit_bits: std.atomic.Value(u64) = .init(0);

pub fn hit(comptime branch: CriticalBranch) void {
    @disableInstrumentation();
    _ = hit_bits.fetchOr(@as(u64, 1) << @intFromEnum(branch), .monotonic);
}

export fn invoice_manager_persistence_coverage_reset() void {
    @disableInstrumentation();
    hit_bits.store(0, .monotonic);
}

export fn invoice_manager_persistence_coverage_hit_bits() u64 {
    @disableInstrumentation();
    return hit_bits.load(.monotonic);
}

export fn invoice_manager_persistence_coverage_required_bits() u64 {
    @disableInstrumentation();
    return (@as(u64, 1) << @typeInfo(CriticalBranch).@"enum".fields.len) - 1;
}
