const std = @import("std");

const canonical_inventory_bytes = @embedFile("../../../../tools/contracts/.generated/runtime/v1/route-inventory.json");

pub const Access = enum {
    public,
    protected,
    invalid,

    pub fn text(self: Access) []const u8 {
        return switch (self) {
            .public => "public",
            .protected => "protected",
            .invalid => "invalid",
        };
    }
};

pub const Route = struct {
    path: []const u8,
    method: []const u8,
    operation_id: []const u8,
    owner: []const u8,
    mount_key: []const u8,
    access: Access,
};

pub const RouteOverride = struct {
    path: ?[]const u8 = null,
    method: ?[]const u8 = null,
    operation_id: ?[]const u8 = null,
    owner: ?[]const u8 = null,
    mount_key: ?[]const u8 = null,
    access: ?Access = null,
};

pub const Inventory = struct {
    allocator: std.mem.Allocator,
    routes: []const Route,

    pub fn deinit(self: *Inventory) void {
        for (self.routes) |route| {
            self.allocator.free(route.path);
            self.allocator.free(route.method);
            self.allocator.free(route.operation_id);
            self.allocator.free(route.owner);
            self.allocator.free(route.mount_key);
        }
        self.allocator.free(self.routes);
        self.* = undefined;
    }

    pub fn byOperation(self: *const Inventory, operation_id: []const u8) ?*const Route {
        for (self.routes) |*route| {
            if (std.mem.eql(u8, route.operation_id, operation_id)) return route;
        }
        return null;
    }

    pub fn cloneWithAccess(
        self: *const Inventory,
        allocator: std.mem.Allocator,
        operation_id: []const u8,
        access: Access,
    ) !Inventory {
        return self.cloneWithOverride(allocator, operation_id, .{ .access = access });
    }

    /// Creates an isolated owned copy for drift and policy tests. The source
    /// inventory and embedded canonical bytes remain immutable.
    pub fn cloneWithOverride(
        self: *const Inventory,
        allocator: std.mem.Allocator,
        operation_id: []const u8,
        override: RouteOverride,
    ) !Inventory {
        const routes = try allocator.alloc(Route, self.routes.len);
        var initialized: usize = 0;
        errdefer {
            for (routes[0..initialized]) |route| freeRoute(allocator, route);
            allocator.free(routes);
        }
        var matched = false;
        for (self.routes) |route| {
            const selected = std.mem.eql(u8, route.operation_id, operation_id);
            routes[initialized] = try duplicateRoute(allocator, .{
                .path = if (selected) override.path orelse route.path else route.path,
                .method = if (selected) override.method orelse route.method else route.method,
                .operation_id = if (selected) override.operation_id orelse route.operation_id else route.operation_id,
                .owner = if (selected) override.owner orelse route.owner else route.owner,
                .mount_key = if (selected) override.mount_key orelse route.mount_key else route.mount_key,
                .access = route.access.text(),
            });
            if (selected) {
                routes[initialized].access = override.access orelse route.access;
                matched = true;
            }
            initialized += 1;
        }
        if (!matched) return error.MissingBinding;
        return .{ .allocator = allocator, .routes = routes };
    }
};

pub const Handler = *const fn (std.mem.Allocator, []const u8) anyerror![]u8;

pub const HandlerBinding = struct {
    operation_id: []const u8,
    handler: Handler,
};

pub const Resolved = struct {
    route: *const Route,
    binding: *const HandlerBinding,
};

pub const Resolution = union(enum) {
    found: Resolved,
    method_not_allowed,
    not_found,
};

pub const InventoryError = error{
    InvalidJson,
    ClosedShapeViolation,
    UnsupportedVersion,
    InvalidMethod,
    InvalidPath,
    InvalidOperationId,
    InvalidOwner,
    InvalidMountKey,
    InvalidAccess,
    DuplicateRoute,
    DuplicateOperation,
    DuplicateBinding,
    MissingBinding,
    ExtraBinding,
    P0ContractMismatch,
};

const WireRoute = struct {
    path: []const u8,
    method: []const u8,
    operation_id: []const u8,
    owner: []const u8,
    mount_key: []const u8,
    access: []const u8,
};

const WireInventory = struct {
    format_version: u8,
    routes: []const WireRoute,
};

pub fn loadCanonical(allocator: std.mem.Allocator) !Inventory {
    return parseOwned(allocator, canonical_inventory_bytes);
}

pub fn parseOwned(allocator: std.mem.Allocator, bytes: []const u8) !Inventory {
    var dynamic = std.json.parseFromSlice(std.json.Value, allocator, bytes, .{}) catch |err|
        return if (err == error.DuplicateField) error.ClosedShapeViolation else error.InvalidJson;
    defer dynamic.deinit();
    try validateClosedShape(dynamic.value);

    var parsed = std.json.parseFromSlice(WireInventory, allocator, bytes, .{
        .allocate = .alloc_always,
    }) catch return error.InvalidJson;
    defer parsed.deinit();
    if (parsed.value.format_version != 1) return error.UnsupportedVersion;

    const routes = try allocator.alloc(Route, parsed.value.routes.len);
    var initialized: usize = 0;
    errdefer {
        for (routes[0..initialized]) |route| {
            allocator.free(route.path);
            allocator.free(route.method);
            allocator.free(route.operation_id);
            allocator.free(route.owner);
            allocator.free(route.mount_key);
        }
        allocator.free(routes);
    }
    for (parsed.value.routes) |wire| {
        try validateWireRoute(wire);
        const access: Access = if (std.mem.eql(u8, wire.access, "public"))
            .public
        else if (std.mem.eql(u8, wire.access, "protected"))
            .protected
        else
            return error.InvalidAccess;
        routes[initialized] = try duplicateRoute(allocator, wire);
        routes[initialized].access = access;
        initialized += 1;
    }
    try validateUnique(routes);
    return .{ .allocator = allocator, .routes = routes };
}

pub fn validateBindings(inventory: *const Inventory, bindings: []const HandlerBinding) InventoryError!void {
    for (bindings, 0..) |binding, index| {
        for (bindings[index + 1 ..]) |other| {
            if (std.mem.eql(u8, binding.operation_id, other.operation_id)) return error.DuplicateBinding;
        }
        if (inventory.byOperation(binding.operation_id) == null) return error.ExtraBinding;
    }
    for (inventory.routes) |route| {
        var count: usize = 0;
        for (bindings) |binding| {
            if (std.mem.eql(u8, route.operation_id, binding.operation_id)) count += 1;
        }
        if (count == 0) return error.MissingBinding;
        if (count != 1) return error.DuplicateBinding;
    }
}

pub fn resolve(
    inventory: *const Inventory,
    bindings: []const HandlerBinding,
    method: []const u8,
    path: []const u8,
) Resolution {
    var path_found = false;
    for (inventory.routes) |*route| {
        if (!std.mem.eql(u8, route.path, path)) continue;
        path_found = true;
        if (!std.mem.eql(u8, route.method, method)) continue;
        for (bindings) |*binding| {
            if (std.mem.eql(u8, route.operation_id, binding.operation_id)) {
                return .{ .found = .{ .route = route, .binding = binding } };
            }
        }
        return .not_found;
    }
    return if (path_found) .method_not_allowed else .not_found;
}

pub fn validateP0(inventory: *const Inventory) InventoryError!void {
    if (inventory.routes.len != 1) return error.P0ContractMismatch;
    const route = inventory.routes[0];
    if (!std.mem.eql(u8, route.operation_id, "P0Health") or
        !std.mem.eql(u8, route.method, "get") or
        !std.mem.eql(u8, route.path, "/api/v1/health") or
        !std.mem.eql(u8, route.owner, "p0") or
        !std.mem.eql(u8, route.mount_key, "foundation") or
        route.access != .public)
    {
        return error.P0ContractMismatch;
    }
}

fn validateClosedShape(value: std.json.Value) InventoryError!void {
    if (value != .object) return error.ClosedShapeViolation;
    const root = value.object;
    if (root.count() != 2 or root.get("format_version") == null or root.get("routes") == null) {
        return error.ClosedShapeViolation;
    }
    const routes_value = root.get("routes").?;
    if (routes_value != .array) return error.ClosedShapeViolation;
    const required = [_][]const u8{ "path", "method", "operation_id", "owner", "mount_key", "access" };
    for (routes_value.array.items) |route_value| {
        if (route_value != .object or route_value.object.count() != required.len) {
            return error.ClosedShapeViolation;
        }
        for (required) |field| if (route_value.object.get(field) == null) return error.ClosedShapeViolation;
    }
}

fn validateWireRoute(route: WireRoute) InventoryError!void {
    if (!validMethod(route.method)) return error.InvalidMethod;
    if (route.path.len < "/api/v1/".len or !std.mem.startsWith(u8, route.path, "/api/v1/") or
        std.mem.indexOf(u8, route.path, "//") != null) return error.InvalidPath;
    var segments = std.mem.splitScalar(u8, route.path, '/');
    while (segments.next()) |segment| {
        if (std.mem.eql(u8, segment, ".") or std.mem.eql(u8, segment, "..")) return error.InvalidPath;
    }
    if (!validIdentifier(route.operation_id)) return error.InvalidOperationId;
    if (route.owner.len != 2 or route.owner[0] != 'p' or route.owner[1] < '0' or route.owner[1] > '8') {
        return error.InvalidOwner;
    }
    if (!validMountKey(route.mount_key)) return error.InvalidMountKey;
}

fn validMethod(value: []const u8) bool {
    return std.mem.eql(u8, value, "get") or
        std.mem.eql(u8, value, "head") or
        std.mem.eql(u8, value, "post") or
        std.mem.eql(u8, value, "put") or
        std.mem.eql(u8, value, "delete") or
        std.mem.eql(u8, value, "options") or
        std.mem.eql(u8, value, "trace") or
        std.mem.eql(u8, value, "patch");
}

fn validMountKey(value: []const u8) bool {
    if (value.len == 0) return false;
    if (value[0] < 'a' or value[0] > 'z') return false;
    for (value[1..]) |byte| {
        if ((byte >= 'a' and byte <= 'z') or (byte >= '0' and byte <= '9') or byte == '_') continue;
        return false;
    }
    return true;
}

fn duplicateRoute(allocator: std.mem.Allocator, wire: WireRoute) !Route {
    const path = try allocator.dupe(u8, wire.path);
    errdefer allocator.free(path);
    const method = try allocator.dupe(u8, wire.method);
    errdefer allocator.free(method);
    const operation_id = try allocator.dupe(u8, wire.operation_id);
    errdefer allocator.free(operation_id);
    const owner = try allocator.dupe(u8, wire.owner);
    errdefer allocator.free(owner);
    const mount_key = try allocator.dupe(u8, wire.mount_key);
    errdefer allocator.free(mount_key);
    const access: Access = if (std.mem.eql(u8, wire.access, "public"))
        .public
    else if (std.mem.eql(u8, wire.access, "protected"))
        .protected
    else
        .invalid;
    return .{
        .path = path,
        .method = method,
        .operation_id = operation_id,
        .owner = owner,
        .mount_key = mount_key,
        .access = access,
    };
}

fn freeRoute(allocator: std.mem.Allocator, route: Route) void {
    allocator.free(route.path);
    allocator.free(route.method);
    allocator.free(route.operation_id);
    allocator.free(route.owner);
    allocator.free(route.mount_key);
}

fn validIdentifier(value: []const u8) bool {
    return value.len != 0;
}

fn validateUnique(routes: []const Route) InventoryError!void {
    for (routes, 0..) |route, index| {
        for (routes[index + 1 ..]) |other| {
            if (std.mem.eql(u8, route.operation_id, other.operation_id)) return error.DuplicateOperation;
            if (std.mem.eql(u8, route.method, other.method) and std.mem.eql(u8, route.path, other.path)) {
                return error.DuplicateRoute;
            }
        }
    }
}
