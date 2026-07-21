const std = @import("std");
const runner = @import("shovelerdb_coverage_runner_core.zig");
const fuzz = std.Build.abi.fuzz;

extern fn invoice_manager_persistence_coverage_reset() void;
extern fn invoice_manager_persistence_coverage_hit_bits() u64;
extern fn invoice_manager_persistence_coverage_required_bits() u64;

const Config = struct {
    pub const contract = @import("shovelerdb_persistence_coverage_contract.zig");
    pub const label = "persistence";
    pub const owning_wp = "WP06";
    pub const expected_source_pattern = "src/platform/persistence/{root.zig,store*,durability*,directory_sync*,diagnostic*}";
    pub fn reset() void {
        invoice_manager_persistence_coverage_reset();
    }
    pub fn hitBits() u64 {
        return invoice_manager_persistence_coverage_hit_bits();
    }
    pub fn requiredBits() u64 {
        return invoice_manager_persistence_coverage_required_bits();
    }
    pub fn ownsSourcePath(path: []const u8) bool {
        const relative = runner.sourceRelativePath(
            path,
            "src/platform/persistence/",
            "src\\platform\\persistence\\",
        ) orelse return false;
        if (std.mem.indexOfAny(u8, relative, "/\\") != null) return false;
        return std.mem.eql(u8, relative, "root.zig") or
            std.mem.startsWith(u8, relative, "store") or
            std.mem.startsWith(u8, relative, "durability") or
            std.mem.startsWith(u8, relative, "directory_sync") or
            std.mem.startsWith(u8, relative, "diagnostic");
    }
};

pub const std_options: std.Options = .{ .logFn = runner.log };
pub fn main(init: std.process.Init.Minimal) void {
    runner.runMain(Config, init);
}

export fn runner_test_run(_: u32) void {}
export fn runner_test_name(_: u32) fuzz.Slice {
    return .fromSlice("persistence-coverage");
}
export fn runner_start_input_poller() void {}
export fn runner_stop_input_poller() void {}
export fn runner_futex_wait(_: *const u32, _: u32) bool {
    return true;
}
export fn runner_futex_wake(_: *const u32, _: u32) void {}
export fn runner_broadcast_input(_: u32, _: fuzz.Slice) void {}
