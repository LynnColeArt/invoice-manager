const route_inventory = @import("route_inventory.zig");

pub const Classification = enum {
    public,
    protected,
};

/// Access is fail-closed. Parsing rejects malformed canonical input, while
/// isolated runtime drift with missing or invalid access remains protected.
pub fn classify(route: *const route_inventory.Route) Classification {
    return switch (route.access) {
        .public => .public,
        .protected, .invalid => .protected,
    };
}
