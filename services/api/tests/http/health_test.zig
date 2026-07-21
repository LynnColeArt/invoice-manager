const std = @import("std");
const http = @import("http");
const server = http.server;

const bindings = [_]http.route_inventory.HandlerBinding{.{
    .operation_id = "P0Health",
    .handler = http.health.respond,
}};

test "health dispatch returns the closed ready envelope with unique canonical request ids" {
    var calls: usize = 0;
    var inventory = try http.route_inventory.loadCanonical(std.testing.allocator);
    defer inventory.deinit();
    var context = server.DispatchContext{ .handler_calls = &calls, .io = std.testing.io };
    var first = try server.dispatch(std.testing.allocator, &inventory, &bindings, .{ .method = "get", .path = "/api/v1/health" }, &context);
    defer first.deinit();
    var second = try server.dispatch(std.testing.allocator, &inventory, &bindings, .{ .method = "get", .path = "/api/v1/health" }, &context);
    defer second.deinit();
    try std.testing.expectEqual(@as(u16, 200), first.status);
    try std.testing.expectEqual(@as(usize, 2), calls);
    try std.testing.expect(std.mem.indexOf(u8, first.body, "\"status\":\"ready\"") != null);
    try std.testing.expect(!std.mem.eql(u8, first.body, second.body));
    try std.testing.expect(std.mem.indexOf(u8, first.body, "path") == null);
}

test "unsupported method unknown path and not-ready state never invoke health" {
    var calls: usize = 0;
    var inventory = try http.route_inventory.loadCanonical(std.testing.allocator);
    defer inventory.deinit();
    var context = server.DispatchContext{ .handler_calls = &calls, .io = std.testing.io };
    var post = try server.dispatch(std.testing.allocator, &inventory, &bindings, .{ .method = "post", .path = "/api/v1/health" }, &context);
    defer post.deinit();
    var unknown = try server.dispatch(std.testing.allocator, &inventory, &bindings, .{ .method = "get", .path = "/api/v1/invoices" }, &context);
    defer unknown.deinit();
    var unavailable = try server.notReadyResponse(std.testing.allocator, std.testing.io);
    defer unavailable.deinit();
    try std.testing.expectEqual(@as(u16, 405), post.status);
    try std.testing.expectEqual(@as(u16, 404), unknown.status);
    try std.testing.expectEqual(@as(u16, 503), unavailable.status);
    try std.testing.expectEqual(@as(usize, 0), calls);
}

test "handler failures become canonical internal envelopes with one RequestId" {
    const Failing = struct {
        fn handle(_: std.mem.Allocator, _: []const u8) anyerror![]u8 {
            return error.SyntheticInternalDiagnostic;
        }
    };
    const failing_bindings = [_]http.route_inventory.HandlerBinding{.{
        .operation_id = "P0Health",
        .handler = Failing.handle,
    }};
    var inventory = try http.route_inventory.loadCanonical(std.testing.allocator);
    defer inventory.deinit();
    var calls: usize = 0;
    var context = server.DispatchContext{ .handler_calls = &calls, .io = std.testing.io };
    var response = try server.dispatch(std.testing.allocator, &inventory, &failing_bindings, .{
        .method = "get",
        .path = "/api/v1/health",
    }, &context);
    defer response.deinit();
    try std.testing.expectEqual(@as(u16, 500), response.status);
    try std.testing.expectEqual(@as(usize, 1), calls);
    try std.testing.expect(std.mem.indexOf(u8, response.body, "internal_error") != null);
    try std.testing.expect(std.mem.indexOf(u8, response.body, "SyntheticInternalDiagnostic") == null);
}
