const std = @import("std");
const http = @import("http");
const route_inventory = http.route_inventory;
const server = http.server;

const canonical_bytes =
    "{\"format_version\":1,\"routes\":[{\"access\":\"public\",\"method\":\"get\",\"mount_key\":\"foundation\",\"operation_id\":\"P0Health\",\"owner\":\"p0\",\"path\":\"/api/v1/health\"}]}";

fn expectInventoryError(expected: anyerror, bytes: []const u8) !void {
    try std.testing.expectError(expected, route_inventory.parseOwned(std.testing.allocator, bytes));
}

fn healthBindings() [1]route_inventory.HandlerBinding {
    return .{.{
        .operation_id = "P0Health",
        .handler = http.health.respond,
    }};
}

fn parseCanonicalForAllocationCheck(allocator: std.mem.Allocator) !void {
    var inventory = try route_inventory.parseOwned(allocator, canonical_bytes);
    defer inventory.deinit();
    try route_inventory.validateP0(&inventory);
}

test "WP08-ROUTE-POLICY-001 protected canonical mutation never invokes the actual handler" {
    const allocator = std.testing.allocator;
    var inventory = try route_inventory.loadCanonical(allocator);
    defer inventory.deinit();
    try std.testing.expectEqual(@as(usize, 1), inventory.routes.len);
    try std.testing.expectEqual(route_inventory.Access.public, inventory.routes[0].access);
    var mutated_inventory = try inventory.cloneWithAccess(allocator, "P0Health", .protected);
    defer mutated_inventory.deinit();
    const mutated = &mutated_inventory.routes[0];
    try std.testing.expectEqualStrings("P0Health", mutated.operation_id);
    try std.testing.expectEqual(route_inventory.Access.protected, mutated.access);
    try std.testing.expectEqual(route_inventory.Access.public, inventory.routes[0].access);
    try std.testing.expectEqualStrings("get", inventory.routes[0].method);
    try std.testing.expectEqualStrings("/api/v1/health", inventory.routes[0].path);

    var handler_calls: usize = 0;
    var context = server.DispatchContext{
        .handler_calls = &handler_calls,
        .io = std.testing.io,
    };
    const bindings = healthBindings();
    var response = try server.dispatch(allocator, &mutated_inventory, &bindings, .{
        .method = mutated.method,
        .path = mutated.path,
    }, &context);
    defer response.deinit();

    // The public boundary must stop protected routes before their binding.
    // Before T039 enforcement this deliberately observes one handler call.
    try std.testing.expectEqual(@as(usize, 0), handler_calls);
    try std.testing.expectEqual(@as(u16, 404), response.status);
    try std.testing.expect(std.mem.indexOf(u8, response.body, "\"code\":\"route_not_found\"") != null);
}

test "canonical inventory has one exact public P0 health route and no domain routes" {
    var inventory = try route_inventory.loadCanonical(std.testing.allocator);
    defer inventory.deinit();
    try route_inventory.validateP0(&inventory);
    const bindings = healthBindings();
    try route_inventory.validateBindings(&inventory, &bindings);
    try std.testing.expectEqual(@as(usize, 1), inventory.routes.len);
    try std.testing.expect(inventory.byOperation("P0Health") != null);
    try std.testing.expect(inventory.byOperation("CreateInvoice") == null);
    try std.testing.expect(inventory.byOperation("ListClients") == null);
}

test "canonical inventory owns and releases every partial allocation" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        parseCanonicalForAllocationCheck,
        .{},
    );
}

test "P0 startup rejects missing and extra otherwise-valid inventory routes" {
    var empty = try route_inventory.parseOwned(std.testing.allocator, "{\"format_version\":1,\"routes\":[]}");
    defer empty.deinit();
    try std.testing.expectError(error.P0ContractMismatch, route_inventory.validateP0(&empty));

    var extra = try route_inventory.parseOwned(std.testing.allocator, "{\"format_version\":1,\"routes\":[{\"access\":\"public\",\"method\":\"get\",\"mount_key\":\"foundation\",\"operation_id\":\"P0Health\",\"owner\":\"p0\",\"path\":\"/api/v1/health\"},{\"access\":\"protected\",\"method\":\"post\",\"mount_key\":\"foundation\",\"operation_id\":\"Synthetic\",\"owner\":\"p0\",\"path\":\"/api/v1/synthetic\"}]}");
    defer extra.deinit();
    try std.testing.expectError(error.P0ContractMismatch, route_inventory.validateP0(&extra));
}

test "inventory parser rejects noncanonical closed-shape and normalization drift" {
    try expectInventoryError(error.InvalidJson, "{");
    try expectInventoryError(error.UnsupportedVersion, "{\"format_version\":2,\"routes\":[]}");
    try expectInventoryError(error.ClosedShapeViolation, "{\"format_version\":1,\"routes\":[],\"extra\":true}");
    try expectInventoryError(error.ClosedShapeViolation, "{\"format_version\":1,\"routes\":[{\"access\":\"public\",\"method\":\"get\",\"mount_key\":\"foundation\",\"operation_id\":\"P0Health\",\"owner\":\"p0\"}]}");
    try expectInventoryError(error.ClosedShapeViolation, "{\"format_version\":1,\"format_version\":1,\"routes\":[]}");
    try expectInventoryError(error.ClosedShapeViolation, "{\"format_version\":1,\"routes\":[{\"access\":\"public\",\"access\":\"protected\",\"method\":\"get\",\"mount_key\":\"foundation\",\"operation_id\":\"P0Health\",\"owner\":\"p0\",\"path\":\"/api/v1/health\"}]}");
    try expectInventoryError(error.ClosedShapeViolation, "{\"format_version\":1,\"routes\":[{\"access\":\"public\",\"method\":\"get\",\"mount_key\":\"foundation\",\"operation_id\":\"P0Health\",\"owner\":\"p0\",\"path\":\"/api/v1/health\",\"unknown\":true}]}");
    try expectInventoryError(error.ClosedShapeViolation, "{\"format_version\":1,\"routes\":[{\"method\":\"get\",\"mount_key\":\"foundation\",\"operation_id\":\"P0Health\",\"owner\":\"p0\",\"path\":\"/api/v1/health\"}]}");
    try expectInventoryError(error.InvalidMethod, "{\"format_version\":1,\"routes\":[{\"access\":\"public\",\"method\":\"connect\",\"mount_key\":\"foundation\",\"operation_id\":\"P0Health\",\"owner\":\"p0\",\"path\":\"/api/v1/health\"}]}");
    try expectInventoryError(error.InvalidPath, "{\"format_version\":1,\"routes\":[{\"access\":\"public\",\"method\":\"get\",\"mount_key\":\"foundation\",\"operation_id\":\"P0Health\",\"owner\":\"p0\",\"path\":\"/api/v1/../health\"}]}");
    try expectInventoryError(error.InvalidOperationId, "{\"format_version\":1,\"routes\":[{\"access\":\"public\",\"method\":\"get\",\"mount_key\":\"foundation\",\"operation_id\":\"\",\"owner\":\"p0\",\"path\":\"/api/v1/health\"}]}");
    try expectInventoryError(error.InvalidOwner, "{\"format_version\":1,\"routes\":[{\"access\":\"public\",\"method\":\"get\",\"mount_key\":\"foundation\",\"operation_id\":\"P0Health\",\"owner\":\"p9\",\"path\":\"/api/v1/health\"}]}");
    try expectInventoryError(error.InvalidMountKey, "{\"format_version\":1,\"routes\":[{\"access\":\"public\",\"method\":\"get\",\"mount_key\":\"Foundation\",\"operation_id\":\"P0Health\",\"owner\":\"p0\",\"path\":\"/api/v1/health\"}]}");
    try expectInventoryError(error.InvalidMountKey, "{\"format_version\":1,\"routes\":[{\"access\":\"protected\",\"method\":\"get\",\"mount_key\":\"foundation-x\",\"operation_id\":\"protected-operation\",\"owner\":\"p0\",\"path\":\"/api/v1/protected..name\"}]}");
    try expectInventoryError(error.InvalidAccess, "{\"format_version\":1,\"routes\":[{\"access\":\"unknown\",\"method\":\"get\",\"mount_key\":\"foundation\",\"operation_id\":\"P0Health\",\"owner\":\"p0\",\"path\":\"/api/v1/health\"}]}");
}

test "generic parser preserves schema-valid long mounts and protected operation ids" {
    const bytes = "{\"format_version\":1,\"routes\":[{\"access\":\"protected\",\"method\":\"trace\",\"mount_key\":\"foundation_0123456789012345678901234567890123456789012345678901234567890123456789\",\"operation_id\":\"path\",\"owner\":\"p8\",\"path\":\"/api/v1/protected..name\"}]}";
    var inventory = try route_inventory.parseOwned(std.testing.allocator, bytes);
    defer inventory.deinit();
    try std.testing.expectEqual(@as(usize, 1), inventory.routes.len);
    try std.testing.expectEqual(route_inventory.Access.protected, inventory.routes[0].access);
}

test "inventory parser rejects route and operation collisions" {
    try expectInventoryError(error.DuplicateRoute, "{\"format_version\":1,\"routes\":[{\"access\":\"public\",\"method\":\"get\",\"mount_key\":\"foundation\",\"operation_id\":\"P0Health\",\"owner\":\"p0\",\"path\":\"/api/v1/health\"},{\"access\":\"protected\",\"method\":\"get\",\"mount_key\":\"foundation\",\"operation_id\":\"Other\",\"owner\":\"p0\",\"path\":\"/api/v1/health\"}]}");
    try expectInventoryError(error.DuplicateOperation, "{\"format_version\":1,\"routes\":[{\"access\":\"public\",\"method\":\"get\",\"mount_key\":\"foundation\",\"operation_id\":\"P0Health\",\"owner\":\"p0\",\"path\":\"/api/v1/health\"},{\"access\":\"protected\",\"method\":\"post\",\"mount_key\":\"foundation\",\"operation_id\":\"P0Health\",\"owner\":\"p0\",\"path\":\"/api/v1/other\"}]}");
}

test "compiled handlers must agree one-for-one with inventory operation ids" {
    var inventory = try route_inventory.parseOwned(std.testing.allocator, canonical_bytes);
    defer inventory.deinit();
    const none = [_]route_inventory.HandlerBinding{};
    try std.testing.expectError(error.MissingBinding, route_inventory.validateBindings(&inventory, &none));
    const extra = [_]route_inventory.HandlerBinding{
        .{ .operation_id = "P0Health", .handler = http.health.respond },
        .{ .operation_id = "Undeclared", .handler = http.health.respond },
    };
    try std.testing.expectError(error.ExtraBinding, route_inventory.validateBindings(&inventory, &extra));
    const duplicate = [_]route_inventory.HandlerBinding{
        .{ .operation_id = "P0Health", .handler = http.health.respond },
        .{ .operation_id = "P0Health", .handler = http.health.respond },
    };
    try std.testing.expectError(error.DuplicateBinding, route_inventory.validateBindings(&inventory, &duplicate));
}

test "fresh method path and operation mutations alter real resolution or fail startup" {
    var canonical = try route_inventory.loadCanonical(std.testing.allocator);
    defer canonical.deinit();
    const bindings = healthBindings();

    var method_drift = try canonical.cloneWithOverride(std.testing.allocator, "P0Health", .{ .method = "post" });
    defer method_drift.deinit();
    try std.testing.expectError(error.P0ContractMismatch, route_inventory.validateP0(&method_drift));
    try std.testing.expectEqual(route_inventory.Resolution.method_not_allowed, route_inventory.resolve(&method_drift, &bindings, "get", "/api/v1/health"));

    var path_drift = try canonical.cloneWithOverride(std.testing.allocator, "P0Health", .{ .path = "/api/v1/health-drift" });
    defer path_drift.deinit();
    try std.testing.expectError(error.P0ContractMismatch, route_inventory.validateP0(&path_drift));
    try std.testing.expectEqual(route_inventory.Resolution.not_found, route_inventory.resolve(&path_drift, &bindings, "get", "/api/v1/health"));

    var operation_drift = try canonical.cloneWithOverride(std.testing.allocator, "P0Health", .{ .operation_id = "DriftedHealth" });
    defer operation_drift.deinit();
    try std.testing.expectError(error.P0ContractMismatch, route_inventory.validateP0(&operation_drift));
    try std.testing.expectError(error.ExtraBinding, route_inventory.validateBindings(&operation_drift, &bindings));

    var owner_drift = try canonical.cloneWithOverride(std.testing.allocator, "P0Health", .{ .owner = "p1" });
    defer owner_drift.deinit();
    try std.testing.expectError(error.P0ContractMismatch, route_inventory.validateP0(&owner_drift));

    var mount_drift = try canonical.cloneWithOverride(std.testing.allocator, "P0Health", .{ .mount_key = "foundation_drift" });
    defer mount_drift.deinit();
    try std.testing.expectError(error.P0ContractMismatch, route_inventory.validateP0(&mount_drift));

    var access_drift = try canonical.cloneWithOverride(std.testing.allocator, "P0Health", .{ .access = .protected });
    defer access_drift.deinit();
    try std.testing.expectError(error.P0ContractMismatch, route_inventory.validateP0(&access_drift));
}

test "missing or invalid effective access defaults protected before handler dispatch" {
    var canonical = try route_inventory.loadCanonical(std.testing.allocator);
    defer canonical.deinit();
    var invalid = try canonical.cloneWithOverride(std.testing.allocator, "P0Health", .{ .access = .invalid });
    defer invalid.deinit();
    const bindings = healthBindings();
    var handler_calls: usize = 0;
    var context = server.DispatchContext{ .handler_calls = &handler_calls, .io = std.testing.io };
    var response = try server.dispatch(std.testing.allocator, &invalid, &bindings, .{
        .method = "get",
        .path = "/api/v1/health",
    }, &context);
    defer response.deinit();
    try std.testing.expectEqual(@as(usize, 0), handler_calls);
    try std.testing.expectEqual(@as(u16, 404), response.status);
}
