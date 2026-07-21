const std = @import("std");
const runner = @import("shovelerdb_coverage_runner_core.zig");
const fuzz = std.Build.abi.fuzz;

extern fn invoice_manager_migration_coverage_reset() void;
extern fn invoice_manager_migration_coverage_hit_bits() u64;
extern fn invoice_manager_migration_coverage_required_bits() u64;

const Config = struct {
    pub const contract = @import("shovelerdb_coverage_contract.zig");
    pub const label = "migration";
    pub fn reset() void {
        invoice_manager_migration_coverage_reset();
    }
    pub fn hitBits() u64 {
        return invoice_manager_migration_coverage_hit_bits();
    }
    pub fn requiredBits() u64 {
        return invoice_manager_migration_coverage_required_bits();
    }
};

pub const std_options: std.Options = .{ .logFn = runner.log };
pub fn main(init: std.process.Init.Minimal) !void {
    try runner.run(Config, init);
}

export fn runner_test_run(_: u32) void {}
export fn runner_test_name(_: u32) fuzz.Slice {
    return .fromSlice("migration-coverage");
}
export fn runner_start_input_poller() void {}
export fn runner_stop_input_poller() void {}
export fn runner_futex_wait(_: *const u32, _: u32) bool {
    return true;
}
export fn runner_futex_wake(_: *const u32, _: u32) void {}
export fn runner_broadcast_input(_: u32, _: fuzz.Slice) void {}
