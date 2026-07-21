const std = @import("std");
const composition = @import("composition");
const migrations = @import("migrations");
const persistence = @import("persistence");

const migration_roots = [_]migrations.OwnerRoot{.{
    .owner = "p0",
    .path = "services/api/migrations/p0",
}};

fn databasePath(allocator: std.mem.Allocator, tmp: *const std.testing.TmpDir, suffix: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/{s}.shovel", .{ tmp.sub_path, suffix });
}

fn unusedLoopbackAddress() !std.Io.net.IpAddress {
    var candidate = try std.Io.net.IpAddress.parse("127.0.0.1", 0);
    var reservation = try candidate.listen(std.testing.io, .{ .reuse_address = false });
    const selected = reservation.socket.address;
    reservation.deinit(std.testing.io);
    return selected;
}

fn expectUnbound(address: std.Io.net.IpAddress) !void {
    var select_buffer: [2]ProbeSelect = undefined;
    var select = std.Io.Select(ProbeSelect).init(std.testing.io, &select_buffer);
    select.async(.connect, probeConnect, .{address});
    select.async(.timeout, waitProbeTimeout, .{});
    const selected = select.await() catch |err| switch (err) {
        error.Canceled => {
            drainProbeSelect(&select);
            return error.Canceled;
        },
    };
    drainProbeSelect(&select);
    switch (selected) {
        .timeout => return error.ProbeTimeout,
        .connect => |result| switch (result) {
            .connect_refused => return,
            .connected => |stream| {
                stream.close(std.testing.io);
                return error.UnexpectedListeningSocket;
            },
            .connect_failed => return error.ProbeFailed,
        },
    }
}

fn drainProbeSelect(select: *std.Io.Select(ProbeSelect)) void {
    while (select.cancel()) |remaining| switch (remaining) {
        .timeout => {},
        .connect => |result| switch (result) {
            .connected => |stream| stream.close(std.testing.io),
            .connect_refused, .connect_failed => {},
        },
    };
}

const ProbeResult = union(enum) {
    connected: std.Io.net.Stream,
    connect_refused,
    connect_failed,
};

const ProbeSelect = union(enum) {
    connect: ProbeResult,
    timeout,
};

fn probeConnect(address: std.Io.net.IpAddress) ProbeResult {
    const stream = address.connect(std.testing.io, .{ .mode = .stream }) catch |err| switch (err) {
        error.ConnectionRefused, error.Timeout => return .connect_refused,
        else => return .connect_failed,
    };
    return .{ .connected = stream };
}

fn waitProbeTimeout() void {
    const duration = std.Io.Clock.Duration{ .raw = .fromMilliseconds(100), .clock = .awake };
    duration.sleep(std.testing.io) catch {};
}

test "startup configuration is infrastructure-only bounded and loopback-safe" {
    var environment = std.process.Environ.Map.init(std.testing.allocator);
    defer environment.deinit();
    try environment.put("INVOICE_API_BIND", "127.0.0.1");
    try environment.put("INVOICE_API_PORT", "0");
    try environment.put("INVOICE_DATABASE_PATH", ".zig-cache/tmp/wp08-startup.shovel");
    const config = try composition.parseConfig(&environment);
    try std.testing.expectEqualStrings("127.0.0.1", config.bind_address);
    try std.testing.expectEqual(@as(u16, 0), config.port);
    try std.testing.expectEqualStrings(".zig-cache/tmp/wp08-startup.shovel", config.database_path);

    try environment.put("INVOICE_API_BIND", "0.0.0.0");
    try std.testing.expectError(error.InvalidBindAddress, composition.parseConfig(&environment));
    try environment.put("INVOICE_API_BIND", "127.0.0.1");
    try environment.put("INVOICE_API_PORT", "65536");
    try std.testing.expectError(error.InvalidPort, composition.parseConfig(&environment));
}

test "WP06 open failure matrix never advances to a listener or fallback" {
    const cases = [_]struct {
        suffix: []const u8,
        faults: persistence.testing.Faults,
        expected: anyerror,
        seed_existing: bool = false,
    }{
        .{ .suffix = "canonicalization", .faults = .{ .canonicalization = true }, .expected = error.CanonicalizationFailed },
        .{ .suffix = "identity", .faults = .{ .identity_inspection = true }, .expected = error.LeaseAcquireFailed, .seed_existing = true },
        .{ .suffix = "registration", .faults = .{ .registration = true }, .expected = error.OutOfMemory },
        .{ .suffix = "lease", .faults = .{ .lease_acquire = true }, .expected = error.LeaseAcquireFailed },
        .{ .suffix = "engine", .faults = .{ .engine_open = true }, .expected = error.EngineOpenFailed },
    };
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    for (cases) |case| {
        const path = try databasePath(std.testing.allocator, &tmp, case.suffix);
        defer std.testing.allocator.free(path);
        if (case.seed_existing) {
            var seeded = try persistence.Store.open(std.testing.allocator, std.testing.io, path);
            try seeded.shutdown();
        }
        const address = try unusedLoopbackAddress();
        const config = composition.Config{
            .bind_address = "127.0.0.1",
            .port = address.getPort(),
            .database_path = path,
        };
        var observation = composition.StartupObservation{};
        try std.testing.expectError(
            case.expected,
            composition.testing.startWithFaults(
                std.testing.allocator,
                std.testing.io,
                config,
                &migration_roots,
                case.faults,
                &observation,
            ),
        );
        try std.testing.expectEqual(@as(usize, 0), observation.bind_attempts);
        try expectUnbound(address);
        var reusable = try persistence.Store.open(std.testing.allocator, std.testing.io, path);
        try std.testing.expectEqual(persistence.State.ready, reusable.state());
        try reusable.shutdown();
    }
}

test "WP06 mutation recovery and handle failure classes use the causal no-bind path" {
    const cases = [_]struct {
        suffix: []const u8,
        faults: persistence.testing.Faults,
        expected: anyerror,
    }{
        .{ .suffix = "executor", .faults = .{ .executor_registration = true }, .expected = error.AllocationFailureCleanup },
        .{ .suffix = "transaction", .faults = .{ .transaction_begin = true }, .expected = error.CorruptAppliedHistory },
        .{ .suffix = "callback", .faults = .{ .callback = true }, .expected = error.CorruptAppliedHistory },
        .{ .suffix = "commit", .faults = .{ .commit = true }, .expected = error.CorruptAppliedHistory },
        .{ .suffix = "directory-open", .faults = .{ .directory_open = true }, .expected = error.MigrationsNotReady },
        .{ .suffix = "directory-close", .faults = .{ .directory_close = true }, .expected = error.MigrationsNotReady },
        .{ .suffix = "reopen", .faults = .{ .reopen = true }, .expected = error.ReopenFailure },
        .{ .suffix = "dirty-discard", .faults = .{ .callback = true, .dirty_discard = true }, .expected = error.RecoveryQuarantine },
    };
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    for (cases) |case| {
        try expectFaultStartupFailure(&tmp, case.suffix, &migration_roots, case.faults, case.expected);
    }

    const lease_path = try databasePath(std.testing.allocator, &tmp, "real-lease");
    defer std.testing.allocator.free(lease_path);
    var lease_holder = try persistence.Store.open(std.testing.allocator, std.testing.io, lease_path);
    defer lease_holder.shutdown() catch @panic("test lease holder shutdown failed");
    const lease_address = try unusedLoopbackAddress();
    var lease_observation = composition.StartupObservation{};
    try std.testing.expectError(error.LeaseConflict, composition.testing.startWithFaults(
        std.testing.allocator,
        std.testing.io,
        .{
            .bind_address = "127.0.0.1",
            .port = lease_address.getPort(),
            .database_path = lease_path,
        },
        &migration_roots,
        .{},
        &lease_observation,
    ));
    try std.testing.expectEqual(@as(usize, 0), lease_observation.bind_attempts);
    try expectUnbound(lease_address);
}

test "seeded durable snapshot survives precommit startup failures and reopens as no-op" {
    const cases = [_]struct {
        suffix: []const u8,
        faults: persistence.testing.Faults,
        expected: anyerror,
    }{
        .{ .suffix = "seed-executor", .faults = .{ .executor_registration = true }, .expected = error.AllocationFailureCleanup },
        .{ .suffix = "seed-transaction", .faults = .{ .transaction_begin = true }, .expected = error.CorruptAppliedHistory },
        .{ .suffix = "seed-callback", .faults = .{ .callback = true }, .expected = error.CorruptAppliedHistory },
    };
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    for (cases) |case| {
        const path = try databasePath(std.testing.allocator, &tmp, case.suffix);
        defer std.testing.allocator.free(path);
        const seed_address = try unusedLoopbackAddress();
        var seed_observation = composition.StartupObservation{};
        var seeded = try composition.testing.startWithFaults(
            std.testing.allocator,
            std.testing.io,
            .{ .bind_address = "127.0.0.1", .port = seed_address.getPort(), .database_path = path },
            &migration_roots,
            .{},
            &seed_observation,
        );
        try seeded.shutdown(std.testing.io);
        const before_file = try std.Io.Dir.openFile(.cwd(), std.testing.io, path, .{});
        const before_stat = try before_file.stat(std.testing.io);
        before_file.close(std.testing.io);
        const before = try std.Io.Dir.readFileAlloc(.cwd(), std.testing.io, path, std.testing.allocator, .limited(1024 * 1024));
        defer std.testing.allocator.free(before);

        try expectFaultStartupFailure(&tmp, case.suffix, &migration_roots, case.faults, case.expected);
        const after_file = try std.Io.Dir.openFile(.cwd(), std.testing.io, path, .{});
        const after_stat = try after_file.stat(std.testing.io);
        after_file.close(std.testing.io);
        const after = try std.Io.Dir.readFileAlloc(.cwd(), std.testing.io, path, std.testing.allocator, .limited(1024 * 1024));
        defer std.testing.allocator.free(after);
        try std.testing.expectEqualSlices(u8, before, after);
        try std.testing.expectEqual(before_stat.inode, after_stat.inode);

        const reopen_address = try unusedLoopbackAddress();
        var reopen_observation = composition.StartupObservation{};
        var reopened = try composition.testing.startWithFaults(
            std.testing.allocator,
            std.testing.io,
            .{ .bind_address = "127.0.0.1", .port = reopen_address.getPort(), .database_path = path },
            &migration_roots,
            .{},
            &reopen_observation,
        );
        try std.testing.expectEqual(@as(usize, 0), reopened.migration_readiness.applied_count);
        try std.testing.expectEqual(@as(usize, 1), reopened.migration_readiness.already_applied_count);
        try reopened.shutdown(std.testing.io);
    }
}

test "graceful Started shutdown stops listener before surfacing store close failure" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(std.testing.allocator, &tmp, "shutdown-failure");
    defer std.testing.allocator.free(path);
    const address = try unusedLoopbackAddress();
    var observation = composition.StartupObservation{};
    var started = try composition.testing.startWithFaults(
        std.testing.allocator,
        std.testing.io,
        .{
            .bind_address = "127.0.0.1",
            .port = address.getPort(),
            .database_path = path,
        },
        &migration_roots,
        .{ .shutdown = true },
        &observation,
    );
    try std.testing.expectEqual(@as(usize, 1), observation.bind_attempts);
    try std.testing.expectError(error.ShutdownFailed, started.shutdown(std.testing.io));
    var rebound_address = address;
    var rebound = try rebound_address.listen(std.testing.io, .{ .reuse_address = true });
    rebound.deinit(std.testing.io);
}

test "fresh startup no-op restart and listener construction require typed readiness" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(std.testing.allocator, &tmp, "startup-success");
    defer std.testing.allocator.free(path);

    const first_address = try unusedLoopbackAddress();
    var first_observation = composition.StartupObservation{};
    var first = try composition.testing.startWithFaults(
        std.testing.allocator,
        std.testing.io,
        .{
            .bind_address = "127.0.0.1",
            .port = first_address.getPort(),
            .database_path = path,
        },
        &migration_roots,
        .{},
        &first_observation,
    );
    var first_open = true;
    defer if (first_open) first.shutdown(std.testing.io) catch @panic("test started shutdown failed");
    try std.testing.expect(first.migration_readiness.isReady());
    try std.testing.expectEqual(@as(usize, 1), first.migration_readiness.applied_count);
    try std.testing.expectEqual(@as(usize, 1), first_observation.bind_attempts);
    try first.shutdown(std.testing.io);
    first_open = false;

    const second_address = try unusedLoopbackAddress();
    var second_observation = composition.StartupObservation{};
    var second = try composition.testing.startWithFaults(
        std.testing.allocator,
        std.testing.io,
        .{
            .bind_address = "127.0.0.1",
            .port = second_address.getPort(),
            .database_path = path,
        },
        &migration_roots,
        .{},
        &second_observation,
    );
    defer second.shutdown(std.testing.io) catch @panic("test started shutdown failed");
    try std.testing.expect(second.migration_readiness.isReady());
    try std.testing.expectEqual(@as(usize, 0), second.migration_readiness.applied_count);
    try std.testing.expectEqual(@as(usize, 1), second.migration_readiness.already_applied_count);
    try std.testing.expectEqual(@as(usize, 1), second_observation.bind_attempts);

    var not_ready = second.migration_readiness;
    not_ready.status = .revalidation_required;
    const address = try unusedLoopbackAddress();
    try std.testing.expectError(
        error.ServiceNotReady,
        composition.listenWhenReady(std.testing.io, address, &second.store, not_ready),
    );
    try expectUnbound(address);
}

test "durability uncertainty completes then revalidates without replaying DDL" {
    const cases = [_]struct {
        suffix: []const u8,
        faults: persistence.testing.Faults,
        expected: anyerror,
    }{
        .{ .suffix = "checkpoint", .faults = .{ .checkpoint = true }, .expected = error.MigrationsNotReady },
        .{ .suffix = "directory-sync", .faults = .{ .directory_sync = true }, .expected = error.MigrationsNotReady },
        .{ .suffix = "unsupported-sync", .faults = .{ .unsupported_directory_sync = true }, .expected = error.MigrationsNotReady },
    };
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    for (cases) |case| {
        const path = try databasePath(std.testing.allocator, &tmp, case.suffix);
        defer std.testing.allocator.free(path);
        const address = try unusedLoopbackAddress();
        const config = composition.Config{
            .bind_address = "127.0.0.1",
            .port = address.getPort(),
            .database_path = path,
        };
        var observation = composition.StartupObservation{};
        try std.testing.expectError(case.expected, composition.testing.startWithFaults(
            std.testing.allocator,
            std.testing.io,
            config,
            &migration_roots,
            case.faults,
            &observation,
        ));
        try std.testing.expectEqual(@as(usize, 0), observation.bind_attempts);
        try expectUnbound(address);
    }
}

test "transient durability completion revalidates without replaying DDL" {
    const cases = [_]struct {
        suffix: []const u8,
        faults: persistence.testing.Faults,
    }{
        .{ .suffix = "checkpoint-revalidate", .faults = .{ .checkpoint = true } },
        .{ .suffix = "directory-revalidate", .faults = .{ .directory_sync = true } },
        .{ .suffix = "unsupported-revalidate", .faults = .{ .unsupported_directory_sync = true } },
    };
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    for (cases) |case| {
        const path = try databasePath(std.testing.allocator, &tmp, case.suffix);
        defer std.testing.allocator.free(path);
        var store = try persistence.testing.openWithFaults(
            std.testing.allocator,
            std.testing.io,
            path,
            case.faults,
        );
        defer store.shutdown() catch @panic("test store shutdown failed");
        const initial = try migrations.run(
            std.testing.allocator,
            std.testing.io,
            &store,
            &migration_roots,
            "2026-07-21T00:00:00.000Z",
        );
        try std.testing.expectEqual(migrations.ReadinessStatus.durability_unconfirmed, initial.status);
        persistence.testing.setFaults(&store, .{});
        const revalidated = try composition.completeAndRevalidate(
            std.testing.allocator,
            std.testing.io,
            &store,
            &migration_roots,
            initial,
        );
        try std.testing.expect(revalidated.isReady());
        try std.testing.expectEqual(@as(usize, 0), revalidated.applied_count);
        try std.testing.expectEqual(@as(usize, 1), revalidated.already_applied_count);
    }
}

test "WP07 discovery and graph failures leave the address unbound" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(std.testing.allocator, &tmp, "migration-failures");
    defer std.testing.allocator.free(path);
    const address = try unusedLoopbackAddress();
    var observation = composition.StartupObservation{};
    try std.testing.expectError(
        error.DiscoveryFailure,
        composition.testing.startWithFaults(
            std.testing.allocator,
            std.testing.io,
            .{
                .bind_address = "127.0.0.1",
                .port = address.getPort(),
                .database_path = path,
            },
            &.{.{ .owner = "p0", .path = "missing/wp08/p0" }},
            .{},
            &observation,
        ),
    );
    try std.testing.expectEqual(@as(usize, 0), observation.bind_attempts);
    try expectUnbound(address);

    const a = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e40";
    const b = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e41";
    const missing = [_]migrations.Descriptor{
        borrowedDescriptor(a, &.{b}, "p0/a/manifest.json"),
    };
    try std.testing.expectError(error.MissingDependency, migrations.plan(std.testing.allocator, &missing));
    const cycle = [_]migrations.Descriptor{
        borrowedDescriptor(a, &.{b}, "p0/a/manifest.json"),
        borrowedDescriptor(b, &.{a}, "p0/b/manifest.json"),
    };
    try std.testing.expectError(error.DependencyCycle, migrations.plan(std.testing.allocator, &cycle));
    const duplicate = [_]migrations.Descriptor{
        borrowedDescriptor(a, &.{}, "p0/a/manifest.json"),
        borrowedDescriptor(a, &.{}, "p0/b/manifest.json"),
    };
    try std.testing.expectError(error.DuplicateMigrationId, migrations.plan(std.testing.allocator, &duplicate));
    try expectUnbound(address);
}

test "actual startup graph digest and DDL failures are deletion-sensitive no-bind cases" {
    const allocator = std.testing.allocator;
    const bootstrap_id = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f";
    const a = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e40";
    const b = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e41";
    const c = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e50";
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const missing_root = try fixtureRoot(allocator, &tmp, "missing");
    defer allocator.free(missing_root);
    try writeMigrationFixture(allocator, missing_root, a, &.{b}, "CREATE TABLE missing_dependency (body TEXT);\n");
    try expectCausalStartupFailure(allocator, &tmp, "missing-db", &.{.{ .owner = "p0", .path = missing_root }}, error.MissingDependency);

    const cycle_root = try fixtureRoot(allocator, &tmp, "cycle");
    defer allocator.free(cycle_root);
    try writeMigrationFixture(allocator, cycle_root, a, &.{b}, "CREATE TABLE cycle_a (body TEXT);\n");
    try writeMigrationFixture(allocator, cycle_root, b, &.{a}, "CREATE TABLE cycle_b (body TEXT);\n");
    try expectCausalStartupFailure(allocator, &tmp, "cycle-db", &.{.{ .owner = "p0", .path = cycle_root }}, error.DependencyCycle);

    const duplicate_left = try fixtureRoot(allocator, &tmp, "duplicate-left");
    defer allocator.free(duplicate_left);
    const duplicate_right = try fixtureRoot(allocator, &tmp, "duplicate-right");
    defer allocator.free(duplicate_right);
    try writeMigrationFixture(allocator, duplicate_left, a, &.{}, "CREATE TABLE duplicate_left (body TEXT);\n");
    try writeMigrationFixture(allocator, duplicate_right, a, &.{}, "CREATE TABLE duplicate_right (body TEXT);\n");
    try expectCausalStartupFailure(allocator, &tmp, "duplicate-db", &.{
        .{ .owner = "p0", .path = duplicate_left },
        .{ .owner = "p0", .path = duplicate_right },
    }, error.DuplicateMigrationId);

    const digest_root = try fixtureRoot(allocator, &tmp, "digest");
    defer allocator.free(digest_root);
    try writeMigrationFixture(allocator, digest_root, a, &.{}, "CREATE TABLE digest_original (body TEXT);\n");
    const changed_script = try std.fmt.allocPrint(allocator, "{s}/{s}/up.sql", .{ digest_root, a });
    defer allocator.free(changed_script);
    try std.Io.Dir.writeFile(.cwd(), std.testing.io, .{
        .sub_path = changed_script,
        .data = "CREATE TABLE digest_changed (body TEXT);\n",
    });
    try expectCausalStartupFailure(allocator, &tmp, "digest-db", &.{.{ .owner = "p0", .path = digest_root }}, error.ScriptDigestMismatch);

    const descriptor_root = try fixtureRoot(allocator, &tmp, "descriptor-digest");
    defer allocator.free(descriptor_root);
    try writeMigrationFixture(allocator, descriptor_root, a, &.{}, "CREATE TABLE descriptor_digest (body TEXT);\n");
    try corruptDescriptorDigest(allocator, descriptor_root, a);
    try expectCausalStartupFailure(allocator, &tmp, "descriptor-db", &.{.{ .owner = "p0", .path = descriptor_root }}, error.DescriptorDigestMismatch);

    const ddl_root = try fixtureRoot(allocator, &tmp, "ddl");
    defer allocator.free(ddl_root);
    try writeMigrationFixture(allocator, ddl_root, c, &.{bootstrap_id}, "CREATE TABLE broken (\n");
    const ddl_database = try databasePath(allocator, &tmp, "ddl-db");
    defer allocator.free(ddl_database);
    const ddl_address = try unusedLoopbackAddress();
    var ddl_observation = composition.StartupObservation{};
    try std.testing.expectError(error.DdlFailure, composition.testing.startWithFaults(
        allocator,
        std.testing.io,
        .{
            .bind_address = "127.0.0.1",
            .port = ddl_address.getPort(),
            .database_path = ddl_database,
        },
        &.{
            migration_roots[0],
            .{ .owner = "p0", .path = ddl_root },
        },
        .{},
        &ddl_observation,
    ));
    try std.testing.expectEqual(@as(usize, 0), ddl_observation.bind_attempts);
    try expectUnbound(ddl_address);

    const recovery_address = try unusedLoopbackAddress();
    var recovery_observation = composition.StartupObservation{};
    var recovered = try composition.testing.startWithFaults(
        allocator,
        std.testing.io,
        .{
            .bind_address = "127.0.0.1",
            .port = recovery_address.getPort(),
            .database_path = ddl_database,
        },
        &migration_roots,
        .{},
        &recovery_observation,
    );
    try std.testing.expect(recovered.migration_readiness.isReady());
    try std.testing.expectEqual(@as(usize, 0), recovered.migration_readiness.applied_count);
    try std.testing.expectEqual(@as(usize, 1), recovered.migration_readiness.already_applied_count);
    try recovered.shutdown(std.testing.io);
    const after_reopen = try std.Io.Dir.openFile(.cwd(), std.testing.io, ddl_database, .{});
    const after_stat = try after_reopen.stat(std.testing.io);
    after_reopen.close(std.testing.io);
    try std.testing.expect(after_stat.size != 0);
}

fn borrowedDescriptor(
    id: []const u8,
    dependencies: []const []const u8,
    source_path: []const u8,
) migrations.Descriptor {
    return .{
        .id = @constCast(id),
        .owner = @constCast("p0"),
        .name = @constCast("startup_negative"),
        .depends_on = @ptrCast(@constCast(dependencies)),
        .script_path = @constCast("up.sql"),
        .script_digest = @constCast("sha256:68dff6daa265a0c0c6d603994438c43a0af3228fff72e677d9dcd0cd60b1fbd3"),
        .descriptor_digest = @constCast("sha256:0b5af56a66a73c1f0f96b76ad4307a6e3a76f3cd34cb0ba71197a5e90d4e7877"),
        .script = @constCast("CREATE TABLE startup_negative (body TEXT);\n"),
        .source_path = @constCast(source_path),
    };
}

fn fixtureRoot(
    allocator: std.mem.Allocator,
    tmp: *const std.testing.TmpDir,
    name: []const u8,
) ![]u8 {
    const root = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/{s}/p0", .{ tmp.sub_path, name });
    errdefer allocator.free(root);
    try std.Io.Dir.createDirPath(.cwd(), std.testing.io, root);
    return root;
}

fn writeMigrationFixture(
    allocator: std.mem.Allocator,
    root: []const u8,
    id: []const u8,
    dependencies: []const []const u8,
    script: []const u8,
) !void {
    const directory = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ root, id });
    defer allocator.free(directory);
    try std.Io.Dir.createDirPath(.cwd(), std.testing.io, directory);
    const script_path = try std.fmt.allocPrint(allocator, "{s}/up.sql", .{directory});
    defer allocator.free(script_path);
    try std.Io.Dir.writeFile(.cwd(), std.testing.io, .{ .sub_path = script_path, .data = script });

    var script_digest_buffer: [71]u8 = undefined;
    const script_digest = sha256Wire(script, &script_digest_buffer);
    var dependency_json: std.ArrayList(u8) = .empty;
    defer dependency_json.deinit(allocator);
    try dependency_json.append(allocator, '[');
    for (dependencies, 0..) |dependency, index| {
        if (index != 0) try dependency_json.append(allocator, ',');
        try appendJsonString(allocator, &dependency_json, dependency);
    }
    try dependency_json.append(allocator, ']');

    var projection: std.ArrayList(u8) = .empty;
    defer projection.deinit(allocator);
    try projection.appendSlice(allocator, "{\"depends_on\":");
    try projection.appendSlice(allocator, dependency_json.items);
    try projection.appendSlice(allocator, ",\"id\":");
    try appendJsonString(allocator, &projection, id);
    try projection.appendSlice(allocator, ",\"name\":\"startup_fixture\",\"owner\":\"p0\",\"script_digest\":");
    try appendJsonString(allocator, &projection, script_digest);
    try projection.appendSlice(allocator, ",\"script_path\":\"up.sql\"}");
    var descriptor_digest_buffer: [71]u8 = undefined;
    const descriptor_digest = sha256Wire(projection.items, &descriptor_digest_buffer);
    const manifest = try std.fmt.allocPrint(
        allocator,
        "{{\"id\":\"{s}\",\"owner\":\"p0\",\"name\":\"startup_fixture\",\"depends_on\":{s},\"script_path\":\"up.sql\",\"script_digest\":\"{s}\",\"descriptor_digest\":\"{s}\"}}",
        .{ id, dependency_json.items, script_digest, descriptor_digest },
    );
    defer allocator.free(manifest);
    const manifest_path = try std.fmt.allocPrint(allocator, "{s}/manifest.json", .{directory});
    defer allocator.free(manifest_path);
    try std.Io.Dir.writeFile(.cwd(), std.testing.io, .{ .sub_path = manifest_path, .data = manifest });
}

fn expectCausalStartupFailure(
    allocator: std.mem.Allocator,
    tmp: *const std.testing.TmpDir,
    database_suffix: []const u8,
    roots: []const migrations.OwnerRoot,
    expected: anyerror,
) !void {
    const path = try databasePath(allocator, tmp, database_suffix);
    defer allocator.free(path);
    const address = try unusedLoopbackAddress();
    var observation = composition.StartupObservation{};
    try std.testing.expectError(expected, composition.testing.startWithFaults(
        allocator,
        std.testing.io,
        .{
            .bind_address = "127.0.0.1",
            .port = address.getPort(),
            .database_path = path,
        },
        roots,
        .{},
        &observation,
    ));
    try std.testing.expectEqual(@as(usize, 0), observation.bind_attempts);
    try expectUnbound(address);
}

fn expectFaultStartupFailure(
    tmp: *const std.testing.TmpDir,
    database_suffix: []const u8,
    roots: []const migrations.OwnerRoot,
    faults: persistence.testing.Faults,
    expected: anyerror,
) !void {
    const path = try databasePath(std.testing.allocator, tmp, database_suffix);
    defer std.testing.allocator.free(path);
    const address = try unusedLoopbackAddress();
    var observation = composition.StartupObservation{};
    try std.testing.expectError(expected, composition.testing.startWithFaults(
        std.testing.allocator,
        std.testing.io,
        .{
            .bind_address = "127.0.0.1",
            .port = address.getPort(),
            .database_path = path,
        },
        roots,
        faults,
        &observation,
    ));
    try std.testing.expectEqual(@as(usize, 0), observation.bind_attempts);
    try expectUnbound(address);
}

fn corruptDescriptorDigest(
    allocator: std.mem.Allocator,
    root: []const u8,
    id: []const u8,
) !void {
    const path = try std.fmt.allocPrint(allocator, "{s}/{s}/manifest.json", .{ root, id });
    defer allocator.free(path);
    const original = try std.Io.Dir.readFileAlloc(.cwd(), std.testing.io, path, allocator, .limited(4096));
    defer allocator.free(original);
    const changed = try allocator.dupe(u8, original);
    defer allocator.free(changed);
    const marker = "\"descriptor_digest\":\"sha256:";
    const marker_index = std.mem.indexOf(u8, changed, marker) orelse return error.MissingDescriptorDigest;
    const digest_start = marker_index + marker.len;
    if (digest_start + 64 > changed.len) return error.MalformedDescriptorDigest;
    @memset(changed[digest_start .. digest_start + 64], '0');
    try std.Io.Dir.writeFile(.cwd(), std.testing.io, .{ .sub_path = path, .data = changed });
}

fn appendJsonString(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: []const u8,
) !void {
    try output.append(allocator, '"');
    try output.appendSlice(allocator, value);
    try output.append(allocator, '"');
}

fn sha256Wire(bytes: []const u8, output: *[71]u8) []const u8 {
    @memcpy(output[0..7], "sha256:");
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    const hex = std.fmt.bytesToHex(digest, .lower);
    @memcpy(output[7..], &hex);
    return output;
}
