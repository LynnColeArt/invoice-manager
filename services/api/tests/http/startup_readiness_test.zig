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
        error.Canceled => return error.Canceled,
    };
    select.cancelDiscard();
    switch (selected) {
        .timeout => return,
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

test "fresh startup no-op restart and listener construction require typed readiness" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(std.testing.allocator, &tmp, "startup-success");
    defer std.testing.allocator.free(path);

    var store = try persistence.Store.open(std.testing.allocator, std.testing.io, path);
    const first = try composition.establishMigrationReadinessAt(
        std.testing.allocator,
        std.testing.io,
        &store,
        &migration_roots,
    );
    try std.testing.expect(first.isReady());
    try std.testing.expectEqual(@as(usize, 1), first.applied_count);
    var listener = try composition.listenWhenReady(
        std.testing.io,
        try std.Io.net.IpAddress.parse("127.0.0.1", 0),
        &store,
        first,
    );
    try std.testing.expect(listener.address().getPort() != 0);
    listener.deinit(std.testing.io);
    try store.shutdown();

    var reopened = try persistence.Store.open(std.testing.allocator, std.testing.io, path);
    defer reopened.shutdown() catch @panic("test store shutdown failed");
    const second = try composition.establishMigrationReadinessAt(
        std.testing.allocator,
        std.testing.io,
        &reopened,
        &migration_roots,
    );
    try std.testing.expect(second.isReady());
    try std.testing.expectEqual(@as(usize, 0), second.applied_count);
    try std.testing.expectEqual(@as(usize, 1), second.already_applied_count);

    var not_ready = second;
    not_ready.status = .revalidation_required;
    const address = try unusedLoopbackAddress();
    try std.testing.expectError(
        error.ServiceNotReady,
        composition.listenWhenReady(std.testing.io, address, &reopened, not_ready),
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
