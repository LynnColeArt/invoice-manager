const std = @import("std");
const migrations = @import("migrations");

test "bootstrap migration is discovered with immutable exact-byte digests" {
    var discovered = try migrations.discover(
        std.testing.allocator,
        std.testing.io,
        &.{.{ .owner = "p0", .path = "migrations/p0" }},
    );
    defer discovered.deinit();

    try std.testing.expectEqual(@as(usize, 1), discovered.descriptors.len);
    const bootstrap = discovered.descriptors[0];
    try std.testing.expectEqualStrings(
        "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f",
        bootstrap.id,
    );
    try std.testing.expectEqualStrings(
        "68dff6daa265a0c0c6d603994438c43a0af3228fff72e677d9dcd0cd60b1fbd3",
        bootstrap.script_digest,
    );
    try std.testing.expectEqualStrings(
        "9e9b67956c64da3820c33fd36d858e1091aa79d15a418c7391c1cd82b9566088",
        bootstrap.descriptor_digest,
    );
    try std.testing.expectEqualStrings(
        "CREATE TABLE app_schema_migrations (id TEXT, owner TEXT, descriptor_digest TEXT, script_digest TEXT, applied_at TEXT);\n",
        bootstrap.script,
    );
}
