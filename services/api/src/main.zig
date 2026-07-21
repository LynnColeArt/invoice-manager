const std = @import("std");
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
    var store = persistence.Store.open(init.gpa, init.io, config.database_path) catch
        return error.StoreUnavailable;
    var store_open = true;
    errdefer if (store_open) store.shutdown() catch {
        std.debug.print("[api:error] safe shutdown failed\n", .{});
    };
    if (store.state() != .ready) return error.StoreUnavailable;
    const migration_readiness = establishMigrationReadiness(init.gpa, init.io, &store) catch
        return error.MigrationsUnavailable;
    if (!migration_readiness.isReady() or store.state() != .ready) return error.ServiceNotReady;

    var inventory = try http.route_inventory.loadCanonical(init.gpa);
    defer inventory.deinit();
    try http.route_inventory.validateP0(&inventory);
    const bindings = [_]http.route_inventory.HandlerBinding{.{
        .operation_id = "P0Health",
        .handler = http.health.respond,
    }};
    try http.route_inventory.validateBindings(&inventory, &bindings);
    const address = std.Io.net.IpAddress.parse(config.bind_address, config.port) catch
        return error.InvalidConfiguration;
    // Socket construction is deliberately the final startup action, after
    // typed store readiness, migrations, inventory, and binding validation.
    var listener = try http.server.Listener.listen(init.io, address);
    std.debug.print("[api:ready] listening\n", .{});

    var handler_calls: usize = 0;
    var dispatch_context = http.server.DispatchContext{
        .handler_calls = &handler_calls,
        .io = init.io,
    };
    while (true) {
        _ = listener.serveOne(init.gpa, init.io, &inventory, &bindings, &dispatch_context) catch |err| switch (err) {
            error.Canceled => break,
        };
    }
    listener.deinit(init.io);
    store.shutdown() catch return error.ShutdownFailed;
    store_open = false;
}

pub fn establishMigrationReadiness(
    allocator: std.mem.Allocator,
    io: std.Io,
    store: *persistence.Store,
) !migrations.Readiness {
    const roots = &[_]migrations.OwnerRoot{.{
        .owner = "p0",
        .path = "services/api/migrations/p0",
    }};
    return establishMigrationReadinessAt(allocator, io, store, roots);
}

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
