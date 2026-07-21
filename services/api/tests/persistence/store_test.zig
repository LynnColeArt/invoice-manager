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

const monotonic_second = std.Io.Clock.Duration{
    .raw = .fromSeconds(1),
    .clock = .awake,
};

const monotonic_millisecond = std.Io.Clock.Duration{
    .raw = .fromMilliseconds(1),
    .clock = .awake,
};

fn waitForFlag(flag: *const std.atomic.Value(bool)) !void {
    return waitForFlagFor(flag, monotonic_second);
}

fn waitForFlagFor(flag: *const std.atomic.Value(bool), duration: std.Io.Clock.Duration) !void {
    const deadline = std.Io.Clock.Timestamp.fromNow(std.testing.io, duration);
    while (!flag.load(.acquire)) {
        if (std.Io.Clock.Timestamp.now(std.testing.io, .awake).compare(.gte, deadline)) {
            return error.TestTimeout;
        }
        try monotonic_millisecond.sleep(std.testing.io);
    }
}

fn waitForState(store: *const persistence.Store, expected: persistence.State) !void {
    const deadline = std.Io.Clock.Timestamp.fromNow(std.testing.io, monotonic_second);
    while (store.state() != expected) {
        if (std.Io.Clock.Timestamp.now(std.testing.io, .awake).compare(.gte, deadline)) {
            return error.TestTimeout;
        }
        try monotonic_millisecond.sleep(std.testing.io);
    }
}

const ShutdownContext = struct {
    entered: std.atomic.Value(bool) = .init(false),
    release: std.atomic.Value(bool) = .init(false),
    late_callbacks: std.atomic.Value(u32) = .init(0),
};

fn blockingCallback(raw_context: *anyopaque, _: *persistence.Executor) !void {
    const context: *ShutdownContext = @ptrCast(@alignCast(raw_context));
    context.entered.store(true, .release);
    try waitForFlagFor(&context.release, .{
        .raw = .fromSeconds(5),
        .clock = .awake,
    });
}

fn lateCallback(raw_context: *anyopaque, _: *persistence.Executor) !void {
    const context: *ShutdownContext = @ptrCast(@alignCast(raw_context));
    _ = context.late_callbacks.fetchAdd(1, .seq_cst);
}

const OperationThread = struct {
    store: *persistence.Store,
    operation: persistence.WriteOperation,
    done: std.atomic.Value(bool) = .init(false),
    result: ?anyerror = null,

    fn mutate(self: *OperationThread) void {
        _ = self.store.mutate(self.operation) catch |err| {
            self.result = err;
            self.done.store(true, .release);
            return;
        };
        self.done.store(true, .release);
    }

    fn shutdown(self: *OperationThread) void {
        self.store.shutdown() catch |err| {
            self.result = err;
        };
        self.done.store(true, .release);
    }
};

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

test "hard-link aliases cannot acquire independent writer leases" {
    if (std.process.Environ.getPosix(std.testing.environ, "WP06_HARDLINK_PROBE_PATH")) |probe_path| {
        try std.testing.expectError(
            error.LeaseConflict,
            persistence.Store.open(std.testing.allocator, std.testing.io, probe_path),
        );
        return;
    }

    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(allocator, &tmp, "hard-link-original");
    defer allocator.free(path);
    const alias = try databasePath(allocator, &tmp, "hard-link-alias");
    defer allocator.free(alias);

    var created = try persistence.Store.open(allocator, std.testing.io, path);
    try created.shutdown();
    try std.Io.Dir.hardLink(.cwd(), path, .cwd(), alias, std.testing.io, .{});

    // Rejecting every existing multi-link name is identity-safe across
    // processes and avoids a second adapter open before a lease is held.
    try std.testing.expectError(
        error.LeaseConflict,
        persistence.Store.open(allocator, std.testing.io, alias),
    );
    try std.testing.expectError(
        error.LeaseConflict,
        persistence.Store.open(allocator, std.testing.io, path),
    );

    var environment = try std.process.Environ.createMap(std.testing.environ, allocator);
    defer environment.deinit();
    try environment.put("WP06_HARDLINK_PROBE_PATH", alias);
    const result = try std.process.run(allocator, std.testing.io, .{
        .argv = &.{"/proc/self/exe"},
        .environ_map = &environment,
        .timeout = .{ .duration = monotonic_second },
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    try std.testing.expectEqual(std.process.Child.Term{ .exited = 0 }, result.term);

    try std.Io.Dir.deleteFile(.cwd(), std.testing.io, alias);
    var reopened = try persistence.Store.open(allocator, std.testing.io, path);
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
    const result = try std.process.run(allocator, std.testing.io, .{
        .argv = &.{"/proc/self/exe"},
        .environ_map = &environment,
        .timeout = .{ .duration = monotonic_second },
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    try std.testing.expectEqual(std.process.Child.Term{ .exited = 0 }, result.term);
}

test "child process deadlines are monotonic and timeout cleanup kills and reaps" {
    if (std.process.Environ.getPosix(std.testing.environ, "WP06_HANGING_CHILD") != null) {
        try std.Io.Timeout.sleep(.{ .duration = .{
            .raw = .fromSeconds(30),
            .clock = .awake,
        } }, std.testing.io);
        return;
    }

    const allocator = std.testing.allocator;
    var environment = try std.process.Environ.createMap(std.testing.environ, allocator);
    defer environment.deinit();
    try environment.put("WP06_HANGING_CHILD", "1");
    try std.testing.expectError(error.Timeout, std.process.run(allocator, std.testing.io, .{
        .argv = &.{"/proc/self/exe"},
        .environ_map = &environment,
        .timeout = .{ .duration = .{
            .raw = .fromMilliseconds(25),
            .clock = .awake,
        } },
    }));
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

test "identity inspection failure is typed and leaves lease acquisition reusable" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(allocator, &tmp, "identity-inspection");
    defer allocator.free(path);

    var created = try persistence.Store.open(allocator, std.testing.io, path);
    try created.shutdown();
    try std.testing.expectError(
        error.LeaseAcquireFailed,
        persistence.testing.openWithFaults(
            allocator,
            std.testing.io,
            path,
            .{ .identity_inspection = true },
        ),
    );
    var reopened = try persistence.Store.open(allocator, std.testing.io, path);
    try reopened.shutdown();
}

test "registration failure destroys the implementation and releases the lease" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(allocator, &tmp, "registration-cleanup");
    defer allocator.free(path);

    try std.testing.expectError(
        error.OutOfMemory,
        persistence.testing.openWithFaults(
            allocator,
            std.testing.io,
            path,
            .{ .registration = true },
        ),
    );
    var reopened = try persistence.Store.open(allocator, std.testing.io, path);
    try reopened.shutdown();
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

test "public capabilities use non-sequential unguessable nonces and forged tags stay closed" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const first_path = try databasePath(allocator, &tmp, "nonce-first");
    defer allocator.free(first_path);
    const second_path = try databasePath(allocator, &tmp, "nonce-second");
    defer allocator.free(second_path);

    var first = try persistence.Store.open(allocator, std.testing.io, first_path);
    defer first.shutdown() catch {};
    var second = try persistence.Store.open(allocator, std.testing.io, second_path);
    defer second.shutdown() catch {};
    const first_nonce = @intFromEnum(first);
    const second_nonce = @intFromEnum(second);
    try std.testing.expect(first_nonce > std.math.maxInt(usize));
    try std.testing.expect(second_nonce > std.math.maxInt(usize));
    try std.testing.expect(first_nonce != second_nonce);

    var forged: persistence.Store = @enumFromInt(1);
    try std.testing.expectEqual(persistence.State.closed, forged.state());
    var unused: void = {};
    try std.testing.expectError(
        error.StoreClosed,
        forged.mutate(.{ .context = &unused, .run = createProbe }),
    );
    try forged.shutdown();
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
    try std.testing.expectError(error.StoreClosed, store.completeDurability());
}

test "shutdown closes admission before waiting for an active operation" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(allocator, &tmp, "active-shutdown");
    defer allocator.free(path);

    var store = try persistence.Store.open(allocator, std.testing.io, path);
    var context = ShutdownContext{};
    var active = OperationThread{
        .store = &store,
        .operation = .{ .context = &context, .run = blockingCallback },
    };
    const active_thread = try std.Thread.spawn(.{}, OperationThread.mutate, .{&active});
    try waitForFlag(&context.entered);

    var closing = OperationThread{
        .store = &store,
        .operation = .{ .context = &context, .run = lateCallback },
    };
    const shutdown_thread = try std.Thread.spawn(.{}, OperationThread.shutdown, .{&closing});
    // The first callback remains blocked, so observing Closed here proves the
    // shutdown thread has closed admission rather than completed teardown.
    const closing_observed = if (waitForState(&store, .closed)) true else |_| false;
    const completion_refused = if (store.completeDurability()) |_| false else |err| err == error.StoreClosed;

    var late = OperationThread{
        .store = &store,
        .operation = .{ .context = &context, .run = lateCallback },
    };
    const late_thread = try std.Thread.spawn(.{}, OperationThread.mutate, .{&late});
    const refused_before_release = if (waitForFlag(&late.done)) true else |_| false;
    const closing_diagnostic = store.lastDiagnostic();

    context.release.store(true, .release);
    active_thread.join();
    shutdown_thread.join();
    late_thread.join();

    try std.testing.expect(refused_before_release);
    try std.testing.expect(completion_refused);
    try std.testing.expect(closing_observed);
    try std.testing.expectEqual(persistence.State.closed, store.state());
    try std.testing.expectEqual(@as(?persistence.Diagnostic, null), closing_diagnostic);
    try std.testing.expectEqual(@as(?anyerror, error.StoreClosed), late.result);
    try std.testing.expectEqual(@as(u32, 0), context.late_callbacks.load(.seq_cst));
    try std.testing.expectEqual(@as(?anyerror, null), active.result);
    try std.testing.expectEqual(@as(?anyerror, null), closing.result);
    try std.testing.expectEqual(persistence.State.closed, store.state());
    try store.shutdown();
}

test "state and diagnostic observation remain safe while a mutation is active" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(allocator, &tmp, "active-observation");
    defer allocator.free(path);

    var store = try persistence.Store.open(allocator, std.testing.io, path);
    defer store.shutdown() catch {};
    var context = ShutdownContext{};
    var active = OperationThread{
        .store = &store,
        .operation = .{ .context = &context, .run = blockingCallback },
    };
    const active_thread = try std.Thread.spawn(.{}, OperationThread.mutate, .{&active});
    try waitForFlag(&context.entered);
    try std.testing.expectEqual(persistence.State.mutating, store.state());
    try std.testing.expectEqual(@as(?persistence.Diagnostic, null), store.lastDiagnostic());
    context.release.store(true, .release);
    active_thread.join();
    try std.testing.expectEqual(@as(?anyerror, null), active.result);
    try std.testing.expectEqual(persistence.State.ready, store.state());
}

test "corrupt existing storage is refused without changing bytes or metadata" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(allocator, &tmp, "corrupt");
    defer allocator.free(path);
    const corrupt_bytes = "synthetic-corrupt-storage-v1\nnot-a-shovelerdb-snapshot\n";
    try std.Io.Dir.writeFile(.cwd(), std.testing.io, .{
        .sub_path = path,
        .data = corrupt_bytes,
    });

    const before_file = try std.Io.Dir.openFile(.cwd(), std.testing.io, path, .{});
    const before_stat = try before_file.stat(std.testing.io);
    before_file.close(std.testing.io);
    const before = try std.Io.Dir.readFileAlloc(.cwd(), std.testing.io, path, allocator, .limited(4096));
    defer allocator.free(before);

    try std.testing.expectError(
        error.EngineOpenFailed,
        persistence.Store.open(allocator, std.testing.io, path),
    );

    const after_file = try std.Io.Dir.openFile(.cwd(), std.testing.io, path, .{});
    const after_stat = try after_file.stat(std.testing.io);
    after_file.close(std.testing.io);
    const after = try std.Io.Dir.readFileAlloc(.cwd(), std.testing.io, path, allocator, .limited(4096));
    defer allocator.free(after);
    try std.testing.expectEqualSlices(u8, before, after);
    try std.testing.expectEqual(before_stat.inode, after_stat.inode);
    try std.testing.expectEqual(before_stat.size, after_stat.size);
    try std.testing.expectEqual(before_stat.mtime, after_stat.mtime);
    try std.testing.expectEqual(before_stat.permissions, after_stat.permissions);
}
