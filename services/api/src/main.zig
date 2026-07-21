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

pub fn main(init: std.process.Init) !void {
    const config = parseConfig(init.environ_map) catch {
        std.debug.print("[api:error] invalid startup configuration\n", .{});
        return error.InvalidConfiguration;
    };
    var store = persistence.Store.open(init.gpa, init.io, config.database_path) catch {
        std.debug.print("[api:error] durable store unavailable\n", .{});
        return error.StoreUnavailable;
    };
    defer store.shutdown() catch {};
    if (store.state() != .ready) return error.StoreUnavailable;
    const migration_readiness = establishMigrationReadiness(init.gpa, init.io, &store) catch {
        std.debug.print("[api:error] startup migrations unavailable\n", .{});
        return error.MigrationsUnavailable;
    };
    const ready = http.server.compositionRootReadyContext(store.state() == .ready, migration_readiness.isReady()) catch
        return error.ServiceNotReady;
    const address = std.Io.net.IpAddress.parse(config.bind_address, config.port) catch
        return error.InvalidConfiguration;
    var listener = try http.server.Listener.listen(init.io, address, ready);
    defer listener.deinit(init.io);
    std.debug.print("[api:ready] listening\n", .{});

    var handler_calls: usize = 0;
    var dispatch_context = http.server.DispatchContext{
        .ready = true,
        .handler_calls = &handler_calls,
        .io = init.io,
    };
    while (true) {
        try listener.serveOne(init.gpa, init.io, .{
            .operation_id = "P0Health",
            .method = "get",
            .path = "/api/v1/health",
            .access = "public",
        }, &dispatch_context);
    }
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
    var readiness = try migrations.run(
        allocator,
        io,
        store,
        roots,
        "2026-07-21T00:00:00.000Z",
    );
    if (readiness.status == .durability_unconfirmed) {
        readiness = try migrations.completeDurability(store, readiness);
    }
    if (readiness.status == .revalidation_required) {
        readiness = try migrations.run(
            allocator,
            io,
            store,
            roots,
            "2026-07-21T00:00:00.000Z",
        );
    }
    if (!readiness.isReady()) return error.MigrationsNotReady;
    return readiness;
}
