const std = @import("std");
const migrations = @import("migrations");

test "migration integration producer is build-wired" {
    std.testing.refAllDecls(migrations);
}

fn databasePath(allocator: std.mem.Allocator, tmp: *const std.testing.TmpDir) ![]u8 {
    return std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/wp07.shovel", .{tmp.sub_path});
}

test "bootstrap applies durably and an identical reopen run is a no-op" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const database_path = try databasePath(allocator, &tmp);
    defer allocator.free(database_path);

    var store = try migrations.testing.openStoreWithFaults(
        allocator,
        std.testing.io,
        database_path,
        .{},
    );
    const first = try migrations.run(
        allocator,
        std.testing.io,
        &store,
        &.{.{ .owner = "p0", .path = "migrations/p0" }},
        "2026-07-21T12:34:56.789Z",
    );
    try std.testing.expect(first.isReady());
    try std.testing.expectEqual(@as(usize, 1), first.applied_count);
    try std.testing.expectEqual(@as(usize, 0), first.already_applied_count);
    try store.shutdown();

    store = try migrations.testing.openStoreWithFaults(
        allocator,
        std.testing.io,
        database_path,
        .{},
    );
    defer store.shutdown() catch {};
    const second = try migrations.run(
        allocator,
        std.testing.io,
        &store,
        &.{.{ .owner = "p0", .path = "migrations/p0" }},
        "2026-07-21T12:34:56.789Z",
    );
    try std.testing.expect(second.isReady());
    try std.testing.expectEqual(@as(usize, 0), second.applied_count);
    try std.testing.expectEqual(@as(usize, 1), second.already_applied_count);
}
