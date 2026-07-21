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
        "sha256:68dff6daa265a0c0c6d603994438c43a0af3228fff72e677d9dcd0cd60b1fbd3",
        bootstrap.script_digest,
    );
    try std.testing.expectEqualStrings(
        "sha256:0b5af56a66a73c1f0f96b76ad4307a6e3a76f3cd34cb0ba71197a5e90d4e7877",
        bootstrap.descriptor_digest,
    );
    try std.testing.expectEqualStrings(
        "CREATE TABLE app_schema_migrations (id TEXT, owner TEXT, descriptor_digest TEXT, script_digest TEXT, applied_at TEXT);\n",
        bootstrap.script,
    );
    try std.testing.expect(bootstrap.script.len > 1);
    try std.testing.expectEqual(@as(u8, '\n'), bootstrap.script[bootstrap.script.len - 1]);
    try std.testing.expect(bootstrap.script[bootstrap.script.len - 2] != '\n');
    try std.testing.expect(std.mem.indexOf(u8, bootstrap.script, "invoice") == null);
    try std.testing.expect(std.mem.indexOf(u8, bootstrap.script, "client") == null);
    try std.testing.expect(std.mem.indexOf(u8, bootstrap.script, "bank") == null);
    try std.testing.expectError(
        error.FileNotFound,
        std.Io.Dir.access(
            .cwd(),
            std.testing.io,
            "migrations/p0/018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f/down.sql",
            .{},
        ),
    );
}

const DigestVector = struct {
    projection_input: struct {
        id: []const u8,
        owner: []const u8,
        name: []const u8,
        depends_on: []const []const u8,
        script_path: []const u8,
        script_digest: []const u8,
    },
    expected_sorted_depends_on: []const []const u8,
    canonical_utf8: []const u8,
    canonical_byte_length: usize,
    canonical_utf8_hex: []const u8,
    expected_sha256: []const u8,
};

fn sha256Wire(bytes: []const u8, output: *[71]u8) []const u8 {
    @memcpy(output[0..7], "sha256:");
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    const hex = std.fmt.bytesToHex(digest, .lower);
    @memcpy(output[7..], &hex);
    return output;
}

test "fixed JCS vector sorts a copy and preserves exact canonical bytes" {
    const bytes = try std.Io.Dir.readFileAlloc(
        .cwd(),
        std.testing.io,
        "tests/persistence/migrations_digest_vector.json",
        std.testing.allocator,
        .limited(64 * 1024),
    );
    defer std.testing.allocator.free(bytes);
    var parsed = try std.json.parseFromSlice(DigestVector, std.testing.allocator, bytes, .{
        .ignore_unknown_fields = true,
    });
    defer parsed.deinit();
    const vector = parsed.value;
    try std.testing.expect(std.mem.lessThan(
        u8,
        vector.projection_input.depends_on[1],
        vector.projection_input.depends_on[0],
    ));

    const canonical = try migrations.canonicalProjection(
        std.testing.allocator,
        vector.projection_input.id,
        vector.projection_input.owner,
        vector.projection_input.name,
        vector.projection_input.depends_on,
        vector.projection_input.script_path,
        vector.projection_input.script_digest,
    );
    defer std.testing.allocator.free(canonical);
    try std.testing.expectEqualStrings(vector.canonical_utf8, canonical);
    try std.testing.expectEqual(vector.canonical_byte_length, canonical.len);
    try std.testing.expectEqualStrings(
        vector.expected_sorted_depends_on[0],
        vector.projection_input.depends_on[1],
    );
    try std.testing.expectEqualStrings(
        vector.expected_sorted_depends_on[1],
        vector.projection_input.depends_on[0],
    );

    const canonical_hex = try std.testing.allocator.alloc(u8, canonical.len * 2);
    defer std.testing.allocator.free(canonical_hex);
    const alphabet = "0123456789abcdef";
    for (canonical, 0..) |byte, index| {
        canonical_hex[index * 2] = alphabet[byte >> 4];
        canonical_hex[index * 2 + 1] = alphabet[byte & 0x0f];
    }
    try std.testing.expectEqualStrings(vector.canonical_utf8_hex, canonical_hex);
    var digest_buffer: [71]u8 = undefined;
    try std.testing.expectEqualStrings(vector.expected_sha256, sha256Wire(canonical, &digest_buffer));
}

fn borrowedDescriptor(
    id: []const u8,
    dependencies: []const []const u8,
    source_path: []const u8,
) migrations.Descriptor {
    const mutable_dependencies: [][]u8 = @ptrCast(@constCast(dependencies));
    return .{
        .id = @constCast(id),
        .owner = @constCast("p0"),
        .name = @constCast("synthetic_plan"),
        .depends_on = mutable_dependencies,
        .script_path = @constCast("up.sql"),
        .script_digest = @constCast("sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"),
        .descriptor_digest = @constCast("sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"),
        .script = @constCast("CREATE TABLE synthetic_plan (body TEXT);\n"),
        .source_path = @constCast(source_path),
    };
}

test "dependency DAG controls order and UUID is only the ready-node tie-break" {
    const a = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e40";
    const b = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e41";
    const c = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e42";
    const d = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e43";
    const descriptors = [_]migrations.Descriptor{
        borrowedDescriptor(d, &.{ b, c }, "p0/d/manifest.json"),
        borrowedDescriptor(c, &.{a}, "p0/c/manifest.json"),
        borrowedDescriptor(a, &.{}, "p0/a/manifest.json"),
        borrowedDescriptor(b, &.{a}, "p0/b/manifest.json"),
    };
    var result = try migrations.plan(std.testing.allocator, &descriptors);
    defer result.deinit();
    const expected = [_][]const u8{ a, b, c, d };
    for (result.order, expected) |index, expected_id| {
        try std.testing.expectEqualStrings(expected_id, descriptors[index].id);
    }
}

test "cycle diagnostics contain stable sorted migration identities" {
    const a = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e40";
    const b = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e41";
    const descriptors = [_]migrations.Descriptor{
        borrowedDescriptor(b, &.{a}, "p0/b/manifest.json"),
        borrowedDescriptor(a, &.{b}, "p0/a/manifest.json"),
    };
    var diagnostic = migrations.PlanDiagnostic{};
    try std.testing.expectError(
        error.DependencyCycle,
        migrations.planWithDiagnostic(std.testing.allocator, &descriptors, &diagnostic),
    );
    try std.testing.expectEqual(migrations.CriticalCategory.dependency_cycle, diagnostic.category.?);
    try std.testing.expectEqualStrings(a, diagnostic.id(0).?);
    try std.testing.expectEqualStrings(b, diagnostic.id(1).?);
}
