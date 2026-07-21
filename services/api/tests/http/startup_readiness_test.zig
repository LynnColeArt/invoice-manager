const std = @import("std");
const composition = @import("composition");
const http = @import("http");

test "startup configuration is infrastructure-only bounded and loopback-safe" {
    var environment = std.process.Environ.Map.init(std.testing.allocator);
    defer environment.deinit();
    try environment.put("INVOICE_API_BIND", "127.0.0.1");
    try environment.put("INVOICE_API_PORT", "0");
    try environment.put("INVOICE_DATABASE_PATH", ".zig-cache/tmp/wp08-startup.shovel");
    const config = try composition.parseConfig(&environment);
    try std.testing.expectEqualStrings("127.0.0.1", config.bind_address);
    try std.testing.expectEqual(@as(u16, 0), config.port);
    try std.testing.expectEqualStrings(".zig-cache/tmp/wp08-startup.shovel", config.database_path);

    try environment.put("INVOICE_API_BIND", "0.0.0.0");
    try std.testing.expectError(error.InvalidBindAddress, composition.parseConfig(&environment));
    try environment.put("INVOICE_API_BIND", "127.0.0.1");
    try environment.put("INVOICE_API_PORT", "65536");
    try std.testing.expectError(error.InvalidPort, composition.parseConfig(&environment));
}

test "neither store-only nor migration-only readiness can construct a listener capability" {
    try std.testing.expectError(error.NotReady, http.server.compositionRootReadyContext(false, false));
    try std.testing.expectError(error.NotReady, http.server.compositionRootReadyContext(true, false));
    try std.testing.expectError(error.NotReady, http.server.compositionRootReadyContext(false, true));
}

test "both typed readiness decisions precede socket construction and ephemeral bind" {
    const ready = try http.server.compositionRootReadyContext(true, true);
    const address = try std.Io.net.IpAddress.parse("127.0.0.1", 0);
    var listener = try http.server.Listener.listen(std.testing.io, address, ready);
    defer listener.deinit(std.testing.io);
    try std.testing.expect(listener.address().getPort() != 0);
}
