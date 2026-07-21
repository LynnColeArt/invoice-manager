const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const contract = @import("migration_coverage_contract");
const fuzz = std.Build.abi.fuzz;

pub const std_options: std.Options = .{ .logFn = log };
var logged_errors: usize = 0;

extern fn invoice_manager_migration_coverage_reset() void;
extern fn invoice_manager_migration_coverage_hit_bits() u64;
extern fn invoice_manager_migration_coverage_required_bits() u64;

pub fn main(init: std.process.Init.Minimal) !void {
    @disableInstrumentation();
    const counters = coverageCounters();
    const pcs = coveragePcs();
    if (counters.len == 0 or counters.len != pcs.len) return contract.CoverageError.MissingMeasurement;

    const allocator = std.heap.page_allocator;
    const aggregate = try allocator.alloc(u8, counters.len);
    defer allocator.free(aggregate);
    @memset(aggregate, 0);

    var critical_tests_seen: u64 = 0;
    var passed: usize = 0;
    var skipped: usize = 0;
    for (builtin.test_functions) |test_fn| {
        @memset(counters, 0);
        invoice_manager_migration_coverage_reset();
        logged_errors = 0;
        testing.allocator_instance = .{};
        testing.io_instance = .init(testing.allocator, .{
            .argv0 = .init(init.args),
            .environ = init.environ,
        });
        testing.environ = init.environ;
        testing.log_level = .warn;
        const result = test_fn.func();
        testing.io_instance.deinit();
        const leaked = testing.allocator_instance.deinit() == .leak;
        if (leaked) return error.TestMemoryLeak;

        if (result) |_| {
            passed += 1;
        } else |err| switch (err) {
            error.SkipZigTest => {
                if (std.mem.indexOf(u8, test_fn.name, contract.critical_test_prefix) != null) {
                    return error.CriticalBranchTestSkipped;
                }
                skipped += 1;
                continue;
            },
            else => return err,
        }
        if (logged_errors != 0) return error.TestLoggedError;

        var production_delta: usize = 0;
        for (counters, aggregate) |counter, *observed| {
            if (counter == 0) continue;
            production_delta += 1;
            observed.* = 1;
        }

        if (contract.branchIndexFromTestName(test_fn.name)) |branch_index| {
            const bit = @as(u64, 1) << @intCast(branch_index);
            if (critical_tests_seen & bit != 0) return error.DuplicateCriticalBranchTest;
            if (production_delta == 0) return error.CriticalBranchDidNotExecuteMigrationLogic;
            if (invoice_manager_migration_coverage_hit_bits() & bit == 0) {
                return error.CriticalBranchProbeNotHit;
            }
            critical_tests_seen |= bit;
        } else if (std.mem.indexOf(u8, test_fn.name, contract.critical_test_prefix) != null) {
            return error.UnknownCriticalBranchTest;
        }
    }

    var seen_sites: usize = 0;
    for (aggregate) |observed| seen_sites += @intFromBool(observed != 0);
    std.debug.print(
        "[coverage-migration] observed {d}/{d} instrumented migration control-flow sites and {d}/{d} critical branch tests before enforcement\n",
        .{
            seen_sites,
            counters.len,
            @popCount(critical_tests_seen),
            contract.critical_branch_count,
        },
    );
    try contract.validateMeasurement(.{
        .seen_sites = seen_sites,
        .total_sites = counters.len,
        .hit_branch_bits = critical_tests_seen,
        .required_branch_bits = invoice_manager_migration_coverage_required_bits(),
    });
    std.debug.print(
        "[coverage-migration] measured {d}/{d} migration control-flow sites ({d}% minimum); {d}/{d} critical branch tests passed; {d} tests passed; {d} skipped\n",
        .{
            seen_sites,
            counters.len,
            contract.minimum_percent,
            @popCount(critical_tests_seen),
            contract.critical_branch_count,
            passed,
            skipped,
        },
    );
}

fn log(
    comptime level: std.log.Level,
    comptime scope: @EnumLiteral(),
    comptime format: []const u8,
    args: anytype,
) void {
    @disableInstrumentation();
    if (@intFromEnum(level) <= @intFromEnum(std.log.Level.err)) logged_errors +|= 1;
    if (@intFromEnum(level) <= @intFromEnum(testing.log_level)) {
        std.debug.print("[{s}] {s}: " ++ format ++ "\n", .{ @tagName(scope), @tagName(level) } ++ args);
    }
}

fn coverageCounters() []u8 {
    @disableInstrumentation();
    const start = @extern([*]u8, .{ .name = "__start___sancov_cntrs" });
    const end = @extern([*]u8, .{ .name = "__stop___sancov_cntrs" });
    return start[0 .. end - start];
}

fn coveragePcs() []const usize {
    @disableInstrumentation();
    const start = @extern([*]usize, .{ .name = "__start___sancov_pcs1" });
    const end = @extern([*]usize, .{ .name = "__stop___sancov_pcs1" });
    return start[0 .. end - start];
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
