const std = @import("std");
const persistence = @import("persistence");

fn databasePath(allocator: std.mem.Allocator, tmp: *const std.testing.TmpDir, suffix: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/{s}.shovel", .{ tmp.sub_path, suffix });
}

fn createProbe(_: *anyopaque, executor: *persistence.Executor) !void {
    _ = try executor.execute("CREATE TABLE wp06_probe (body TEXT);");
}

const SerializedContext = struct {
    active: *std.atomic.Value(u32),
    overlap: *std.atomic.Value(u32),
};

fn serializedCallback(raw_context: *anyopaque, executor: *persistence.Executor) !void {
    _ = executor;
    const context: *SerializedContext = @ptrCast(@alignCast(raw_context));
    if (context.active.fetchAdd(1, .seq_cst) != 0) {
        _ = context.overlap.fetchAdd(1, .seq_cst);
    }
    var value: usize = 0;
    for (0..200_000) |index| value +%= index;
    std.mem.doNotOptimizeAway(value);
    _ = context.active.fetchSub(1, .seq_cst);
}

fn mutateThread(store: *persistence.Store, context: *SerializedContext, failures: *std.atomic.Value(u32)) void {
    _ = store.mutate(.{ .context = context, .run = serializedCallback }) catch {
        _ = failures.fetchAdd(1, .seq_cst);
        return;
    };
}

test "canonical aliases share one exclusive lease and release it on shutdown" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(allocator, &tmp, "lease");
    defer allocator.free(path);
    const alias = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/./lease.shovel", .{tmp.sub_path});
    defer allocator.free(alias);

    var first = try persistence.Store.open(allocator, std.testing.io, path);
    defer first.shutdown() catch {};
    try std.testing.expectError(error.LeaseConflict, persistence.Store.open(allocator, std.testing.io, alias));

    try first.shutdown();
    var reopened = try persistence.Store.open(allocator, std.testing.io, alias);
    defer reopened.shutdown() catch {};
    try std.testing.expectEqual(persistence.State.ready, reopened.state());
}

test "a second process cannot acquire the live canonical lease" {
    if (std.process.Environ.getPosix(std.testing.environ, "WP06_LEASE_PROBE_PATH")) |probe_path| {
        try std.testing.expectError(
            error.LeaseConflict,
            persistence.Store.open(std.testing.allocator, std.testing.io, probe_path),
        );
        return;
    }

    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(allocator, &tmp, "cross-process-lease");
    defer allocator.free(path);
    var store = try persistence.Store.open(allocator, std.testing.io, path);
    defer store.shutdown() catch {};

    var environment = try std.process.Environ.createMap(std.testing.environ, allocator);
    defer environment.deinit();
    try environment.put("WP06_LEASE_PROBE_PATH", path);
    var child = try std.process.spawn(std.testing.io, .{
        .argv = &.{"/proc/self/exe"},
        .environ_map = &environment,
        .stdin = .ignore,
        .stdout = .ignore,
        .stderr = .ignore,
    });
    try std.testing.expectEqual(std.process.Child.Term{ .exited = 0 }, try child.wait(std.testing.io));
}

test "partial engine-open cleanup releases the filesystem lease" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(allocator, &tmp, "partial-open");
    defer allocator.free(path);

    try std.testing.expectError(
        error.EngineOpenFailed,
        persistence.testing.openWithFaults(allocator, std.testing.io, path, .{ .engine_open = true }),
    );
    var store = try persistence.Store.open(allocator, std.testing.io, path);
    defer store.shutdown() catch {};
    try std.testing.expectEqual(persistence.State.ready, store.state());
}

test "an existing canonical database path retains exact allocator ownership" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(allocator, &tmp, "existing-canonical");
    defer allocator.free(path);

    var first = try persistence.Store.open(allocator, std.testing.io, path);
    try first.shutdown();
    var second = try persistence.Store.open(allocator, std.testing.io, path);
    try second.shutdown();
}

test "one store serializes concurrent mutation callbacks and checkpoints" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(allocator, &tmp, "serialized");
    defer allocator.free(path);

    var store = try persistence.Store.open(allocator, std.testing.io, path);
    defer store.shutdown() catch {};
    var unused: void = {};
    _ = try store.mutate(.{ .context = &unused, .run = createProbe });

    var active = std.atomic.Value(u32).init(0);
    var overlap = std.atomic.Value(u32).init(0);
    var failures = std.atomic.Value(u32).init(0);
    var context = SerializedContext{ .active = &active, .overlap = &overlap };
    const one = try std.Thread.spawn(.{}, mutateThread, .{ &store, &context, &failures });
    const two = try std.Thread.spawn(.{}, mutateThread, .{ &store, &context, &failures });
    one.join();
    two.join();
    try std.testing.expectEqual(@as(u32, 0), failures.load(.seq_cst));
    try std.testing.expectEqual(@as(u32, 0), overlap.load(.seq_cst));
}

test "shutdown is deterministic idempotent and closes the public facade" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(allocator, &tmp, "shutdown");
    defer allocator.free(path);

    var store = try persistence.Store.open(allocator, std.testing.io, path);
    try store.shutdown();
    try store.shutdown();
    try std.testing.expectEqual(persistence.State.closed, store.state());
    var unused: void = {};
    try std.testing.expectError(error.StoreClosed, store.mutate(.{ .context = &unused, .run = createProbe }));
}
