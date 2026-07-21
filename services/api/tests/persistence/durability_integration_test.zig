const std = @import("std");
const persistence = @import("persistence");

fn databasePath(allocator: std.mem.Allocator, tmp: *const std.testing.TmpDir) ![]u8 {
    return std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/cycles.shovel", .{tmp.sub_path});
}

const InsertContext = struct { value: []const u8 };

fn initialize(_: *anyopaque, executor: *persistence.Executor) !void {
    _ = try executor.execute("CREATE TABLE wp06_cycles (body TEXT);");
}

fn insert(raw_context: *anyopaque, executor: *persistence.Executor) !void {
    const context: *InsertContext = @ptrCast(@alignCast(raw_context));
    _ = try executor.executeText("INSERT INTO wp06_cycles VALUES (", context.value, ");");
}

test "real ShovelerDB survives twenty acknowledged checkpoint sync reopen cycles" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try databasePath(allocator, &tmp);
    defer allocator.free(path);

    var store = try persistence.Store.open(allocator, std.testing.io, path);
    var unused: void = {};
    _ = try store.mutate(.{ .context = &unused, .run = initialize });
    try store.shutdown();

    for (0..20) |cycle| {
        store = try persistence.Store.open(allocator, std.testing.io, path);
        const value = try std.fmt.allocPrint(allocator, "cycle-{d}", .{cycle});
        defer allocator.free(value);
        var context = InsertContext{ .value = value };
        const receipt = try store.mutate(.{ .context = &context, .run = insert });
        try std.testing.expectEqual(persistence.State.directory_synchronized, receipt.durability);
        try store.shutdown();

        store = try persistence.Store.open(allocator, std.testing.io, path);
        try std.testing.expectEqual(cycle + 1, try persistence.testing.rowCount(&store, "SELECT body FROM wp06_cycles;"));
        try store.shutdown();
    }
}
