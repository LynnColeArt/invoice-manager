const std = @import("std");
const server = @import("http").server;

const RouteWire = struct {
    access: []const u8,
    method: []const u8,
    mount_key: []const u8,
    operation_id: []const u8,
    owner: []const u8,
    path: []const u8,
};

const InventoryWire = struct {
    format_version: u8,
    routes: []const RouteWire,
};

test "WP08-ROUTE-POLICY-001 protected canonical mutation never invokes the actual handler" {
    const allocator = std.testing.allocator;
    const bytes = try readFreshCanonicalInventory(allocator);
    defer allocator.free(bytes);
    var parsed = try std.json.parseFromSlice(InventoryWire, allocator, bytes, .{
        .allocate = .alloc_always,
    });
    defer parsed.deinit();

    try std.testing.expectEqual(@as(u8, 1), parsed.value.format_version);
    try std.testing.expectEqual(@as(usize, 1), parsed.value.routes.len);
    var mutated = parsed.value.routes[0];
    try std.testing.expectEqualStrings("P0Health", mutated.operation_id);
    try std.testing.expectEqualStrings("public", mutated.access);
    mutated.access = "protected";

    var handler_calls: usize = 0;
    var context = server.DispatchContext{
        .ready = true,
        .handler_calls = &handler_calls,
        .io = std.testing.io,
    };
    var response = try server.dispatch(allocator, .{
        .operation_id = mutated.operation_id,
        .method = mutated.method,
        .path = mutated.path,
        .access = mutated.access,
    }, .{
        .method = mutated.method,
        .path = mutated.path,
    }, &context);
    defer response.deinit();

    // The public boundary must stop protected routes before their binding.
    // Before T039 enforcement this deliberately observes one handler call.
    try std.testing.expectEqual(@as(usize, 0), handler_calls);
}

fn readFreshCanonicalInventory(allocator: std.mem.Allocator) ![]u8 {
    const paths = [_][]const u8{
        "tools/contracts/.generated/runtime/v1/route-inventory.json",
        "../../tools/contracts/.generated/runtime/v1/route-inventory.json",
    };
    for (paths) |path| {
        return std.Io.Dir.cwd().readFileAlloc(
            std.testing.io,
            path,
            allocator,
            .limited(64 * 1024),
        ) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };
    }
    return error.FileNotFound;
}
