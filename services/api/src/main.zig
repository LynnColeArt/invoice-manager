const std = @import("std");
const builtin = @import("builtin");
const persistence = @import("persistence");
const migrations = @import("migrations");
const http = @import("http");

pub const ConfigError = error{
    MissingBindAddress,
    MissingPort,
    MissingDatabasePath,
    InvalidBindAddress,
    InvalidPort,
    UnsafeDatabasePath,
};

pub const Config = struct {
    bind_address: []const u8,
    port: u16,
    database_path: []const u8,
};

pub fn parseConfig(environ: *const std.process.Environ.Map) ConfigError!Config {
    const bind_address = environ.get("INVOICE_API_BIND") orelse return error.MissingBindAddress;
    const port_text = environ.get("INVOICE_API_PORT") orelse return error.MissingPort;
    const database_path = environ.get("INVOICE_DATABASE_PATH") orelse return error.MissingDatabasePath;
    if (!std.mem.eql(u8, bind_address, "127.0.0.1") and !std.mem.eql(u8, bind_address, "::1")) {
        return error.InvalidBindAddress;
    }
    const port = std.fmt.parseInt(u16, port_text, 10) catch return error.InvalidPort;
    if (database_path.len == 0 or database_path.len > 4096 or
        std.mem.indexOf(u8, database_path, "\x00") != null) return error.UnsafeDatabasePath;
    return .{ .bind_address = bind_address, .port = port, .database_path = database_path };
}

pub fn main(init: std.process.Init) u8 {
    run(init) catch {
        std.debug.print("[api:error] startup failed\n", .{});
        return 1;
    };
    return 0;
}

fn run(init: std.process.Init) !void {
    const config = try parseConfig(init.environ_map);
    var started = try startWithOpener(
        init.gpa,
        init.io,
        config,
        &canonical_migration_roots,
        .{ .context = null, .open = openProductionStore },
        null,
    );
    var started_open = true;
    errdefer if (started_open) started.shutdown(init.io) catch {
        std.debug.print("[api:error] safe shutdown failed\n", .{});
    };
    std.debug.print("[api:ready] listening\n", .{});

    var handler_calls: usize = 0;
    var dispatch_context = http.server.DispatchContext{
        .handler_calls = &handler_calls,
        .io = init.io,
    };
    while (true) {
        _ = started.listener.serveOne(init.gpa, init.io, &started.inventory, &health_bindings, &dispatch_context) catch |err| switch (err) {
            error.Canceled => break,
        };
    }
    started_open = false;
    try started.shutdown(init.io);
}

const canonical_migration_roots = [_]migrations.OwnerRoot{.{
    .owner = "p0",
    .path = "services/api/migrations/p0",
}};

const health_bindings = [_]http.route_inventory.HandlerBinding{.{
    .operation_id = "P0Health",
    .handler = http.health.respond,
}};

pub const StartupObservation = struct {
    bind_attempts: usize = 0,
};

const StoreOpener = struct {
    context: ?*anyopaque,
    open: *const fn (?*anyopaque, std.mem.Allocator, std.Io, []const u8) anyerror!persistence.Store,
};

pub const Started = struct {
    store: persistence.Store,
    migration_readiness: migrations.Readiness,
    inventory: http.route_inventory.Inventory,
    listener: http.server.Listener,

    /// Stop accepting before releasing inventory and the durable store.
    pub fn shutdown(self: *Started, io: std.Io) !void {
        self.listener.deinit(io);
        self.inventory.deinit();
        var store = self.store;
        self.* = undefined;
        try store.shutdown();
    }
};

fn openProductionStore(
    _: ?*anyopaque,
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
) !persistence.Store {
    return persistence.Store.open(allocator, io, path);
}

fn startWithOpener(
    allocator: std.mem.Allocator,
    io: std.Io,
    config: Config,
    roots: []const migrations.OwnerRoot,
    opener: StoreOpener,
    observation: ?*StartupObservation,
) !Started {
    const address = std.Io.net.IpAddress.parse(config.bind_address, config.port) catch
        return error.InvalidConfiguration;
    var store = try opener.open(opener.context, allocator, io, config.database_path);
    var store_open = true;
    errdefer if (store_open) store.shutdown() catch {
        std.debug.print("[api:error] safe shutdown failed\n", .{});
    };
    if (store.state() != .ready) return error.StoreUnavailable;
    const migration_readiness = try establishMigrationReadinessAt(allocator, io, &store, roots);
    if (!migration_readiness.isReady() or store.state() != .ready) return error.ServiceNotReady;

    var inventory = try http.route_inventory.loadCanonical(allocator);
    var inventory_open = true;
    errdefer if (inventory_open) inventory.deinit();
    try http.route_inventory.validateP0(&inventory);
    try http.route_inventory.validateBindings(&inventory, &health_bindings);
    if (observation) |value| value.bind_attempts += 1;
    const listener = try listenWhenReady(io, address, &store, migration_readiness);
    store_open = false;
    inventory_open = false;
    return .{
        .store = store,
        .migration_readiness = migration_readiness,
        .inventory = inventory,
        .listener = listener,
    };
}

/// The composition root is the only ordinary constructor for the HTTP ready
/// capability. It consumes the typed WP06/WP07 results before socket creation.
pub fn listenWhenReady(
    io: std.Io,
    address: std.Io.net.IpAddress,
    store: *const persistence.Store,
    migration_readiness: migrations.Readiness,
) !http.server.Listener {
    if (store.state() != .ready or !migration_readiness.isReady()) {
        return error.ServiceNotReady;
    }
    var marker: u8 = 0;
    const ready_context: *const http.server.ReadyContext = @ptrCast(&marker);
    return http.server.Listener.listen(io, address, ready_context);
}

pub fn establishMigrationReadiness(
    allocator: std.mem.Allocator,
    io: std.Io,
    store: *persistence.Store,
) !migrations.Readiness {
    return establishMigrationReadinessAt(allocator, io, store, &canonical_migration_roots);
}

pub const testing = if (builtin.is_test) struct {
    fn openFaultedStore(
        raw_context: ?*anyopaque,
        allocator: std.mem.Allocator,
        io: std.Io,
        path: []const u8,
    ) !persistence.Store {
        const faults: *const persistence.testing.Faults = @ptrCast(@alignCast(raw_context.?));
        return persistence.testing.openWithFaults(allocator, io, path, faults.*);
    }

    pub fn startWithFaults(
        allocator: std.mem.Allocator,
        io: std.Io,
        config: Config,
        roots: []const migrations.OwnerRoot,
        faults: persistence.testing.Faults,
        observation: *StartupObservation,
    ) !Started {
        var fault_context = faults;
        return startWithOpener(
            allocator,
            io,
            config,
            roots,
            .{ .context = &fault_context, .open = openFaultedStore },
            observation,
        );
    }
} else struct {};

pub fn establishMigrationReadinessAt(
    allocator: std.mem.Allocator,
    io: std.Io,
    store: *persistence.Store,
    roots: []const migrations.OwnerRoot,
) !migrations.Readiness {
    var readiness = try migrations.run(
        allocator,
        io,
        store,
        roots,
        "2026-07-21T00:00:00.000Z",
    );
    if (readiness.status == .durability_unconfirmed) {
        readiness = try completeAndRevalidate(allocator, io, store, roots, readiness);
    }
    if (!readiness.isReady()) return error.MigrationsNotReady;
    return readiness;
}

pub fn completeAndRevalidate(
    allocator: std.mem.Allocator,
    io: std.Io,
    store: *persistence.Store,
    roots: []const migrations.OwnerRoot,
    prior: migrations.Readiness,
) !migrations.Readiness {
    const completed = try migrations.completeDurability(store, prior);
    if (completed.status != .revalidation_required or completed.isReady()) {
        return error.MigrationsNotReady;
    }
    const revalidated = try migrations.run(
        allocator,
        io,
        store,
        roots,
        "2026-07-21T00:00:00.000Z",
    );
    if (!revalidated.isReady()) return error.MigrationsNotReady;
    return revalidated;
}
