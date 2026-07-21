const std = @import("std");
const server = @import("http").server;

const route = server.RouteMetadata{
    .operation_id = "P0Health",
    .method = "get",
    .path = "/api/v1/health",
    .access = "public",
};

test "health dispatch returns the closed ready envelope with unique canonical request ids" {
    var calls: usize = 0;
    var context = server.DispatchContext{ .ready = true, .handler_calls = &calls, .io = std.testing.io };
    var first = try server.dispatch(std.testing.allocator, route, .{ .method = "get", .path = "/api/v1/health" }, &context);
    defer first.deinit();
    var second = try server.dispatch(std.testing.allocator, route, .{ .method = "get", .path = "/api/v1/health" }, &context);
    defer second.deinit();
    try std.testing.expectEqual(@as(u16, 200), first.status);
    try std.testing.expectEqual(@as(usize, 2), calls);
    try std.testing.expect(std.mem.indexOf(u8, first.body, "\"status\":\"ready\"") != null);
    try std.testing.expect(!std.mem.eql(u8, first.body, second.body));
    try std.testing.expect(std.mem.indexOf(u8, first.body, "path") == null);
}

test "unsupported method unknown path and not-ready state never invoke health" {
    var calls: usize = 0;
    var context = server.DispatchContext{ .ready = true, .handler_calls = &calls, .io = std.testing.io };
    var post = try server.dispatch(std.testing.allocator, route, .{ .method = "post", .path = route.path }, &context);
    defer post.deinit();
    var unknown = try server.dispatch(std.testing.allocator, route, .{ .method = "get", .path = "/api/v1/invoices" }, &context);
    defer unknown.deinit();
    context.ready = false;
    var unavailable = try server.dispatch(std.testing.allocator, route, .{ .method = "get", .path = route.path }, &context);
    defer unavailable.deinit();
    try std.testing.expectEqual(@as(u16, 405), post.status);
    try std.testing.expectEqual(@as(u16, 404), unknown.status);
    try std.testing.expectEqual(@as(u16, 503), unavailable.status);
    try std.testing.expectEqual(@as(usize, 0), calls);
}
