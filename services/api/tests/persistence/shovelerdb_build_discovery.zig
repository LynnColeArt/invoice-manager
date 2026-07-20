const std = @import("std");
const registry = @import("build_registry");

fn expectPaths(expected: []const []const u8, actual: []const registry.Classified) !void {
    try std.testing.expectEqual(expected.len, actual.len);
    for (expected, actual) |expected_path, entry| {
        try std.testing.expectEqualStrings(expected_path, entry.path);
    }
}

test "stable step names and aggregate order are exact" {
    const expected_steps = [_][]const u8{
        "test-shovelerdb-adapter",
        "test-shovelerdb-integration",
        "test-build-discovery",
        "test-shared",
        "coverage-shared",
        "test-persistence",
        "test-persistence-integration",
        "test-persistence-crash",
        "coverage-persistence",
        "test-migration",
        "test-migration-integration",
        "migration-negative",
        "coverage-migration",
        "test-http",
        "coverage",
        "test",
    };
    try std.testing.expectEqualDeep(expected_steps, registry.stable_step_names);
    try std.testing.expectEqualStrings(
        "npm run contracts:generate",
        registry.http_contract_materializer,
    );

    const expected_test_order = [_][]const u8{
        "test-shovelerdb-adapter",
        "test-shovelerdb-integration",
        "test-build-discovery",
        "test-shared",
        "test-persistence",
        "test-persistence-integration",
        "test-persistence-crash",
        "test-migration",
        "test-migration-integration",
        "migration-negative",
        "test-http",
    };
    try std.testing.expectEqualDeep(expected_test_order, registry.aggregate_test_order);
    try std.testing.expectEqualDeep(
        [_][]const u8{ "coverage-shared", "coverage-persistence", "coverage-migration" },
        registry.aggregate_coverage_order,
    );
}

test "creation order does not change normalized bytewise order" {
    const allocator = std.testing.allocator;
    const first = [_]registry.Candidate{
        .{ .path = "tests/shared/zeta_test.zig" },
        .{ .path = "tests/persistence/store_test.zig" },
        .{ .path = "tests/shared/alpha_test.zig" },
    };
    const second = [_]registry.Candidate{
        .{ .path = "tests/shared/alpha_test.zig" },
        .{ .path = "tests/shared/zeta_test.zig" },
        .{ .path = "tests/persistence/store_test.zig" },
    };

    const first_result = try registry.classifyCandidates(allocator, &first);
    defer registry.deinitClassified(allocator, first_result);
    const second_result = try registry.classifyCandidates(allocator, &second);
    defer registry.deinitClassified(allocator, second_result);

    const expected = [_][]const u8{
        "tests/persistence/store_test.zig",
        "tests/shared/alpha_test.zig",
        "tests/shared/zeta_test.zig",
    };
    try expectPaths(&expected, first_result);
    try expectPaths(&expected, second_result);
}

test "all documented groups classify without ambiguity" {
    const allocator = std.testing.allocator;
    const candidates = [_]registry.Candidate{
        .{ .path = "tests/persistence/shovelerdb_integration.zig" },
        .{ .path = "tests/persistence/shovelerdb_build_discovery.zig" },
        .{ .path = "tests/shared/entity_id_test.zig" },
        .{ .path = "tests/persistence/store_test.zig" },
        .{ .path = "tests/persistence/durability_integration_test.zig" },
        .{ .path = "tests/persistence/store_crash_helper.zig" },
        .{ .path = "tests/persistence/migrations_test.zig" },
        .{ .path = "tests/persistence/migrations_integration_test.zig" },
        .{ .path = "tests/persistence/migrations_negative_test.zig" },
        .{ .path = "tests/http/health_test.zig" },
    };
    const result = try registry.classifyCandidates(allocator, &candidates);
    defer registry.deinitClassified(allocator, result);

    var seen = std.EnumSet(registry.Group).initEmpty();
    for (result) |entry| seen.insert(entry.group);
    inline for (std.meta.fields(registry.Group)) |field| {
        try std.testing.expect(seen.contains(@enumFromInt(field.value)));
    }
}

test "persistence crash wins before integration and migration basenames are exact" {
    try std.testing.expectEqual(
        registry.Group.persistence_crash,
        try registry.classifyNormalized("tests/persistence/store_crash_integration_test.zig"),
    );
    try std.testing.expectEqual(
        registry.Group.persistence_integration,
        try registry.classifyNormalized("tests/persistence/durability_integration_test.zig"),
    );
    try std.testing.expectEqual(
        registry.Group.migration_unit,
        try registry.classifyNormalized("tests/persistence/migrations_test.zig"),
    );
    try std.testing.expectEqual(
        registry.Group.migration_integration,
        try registry.classifyNormalized("tests/persistence/migrations_integration_test.zig"),
    );
    try std.testing.expectEqual(
        registry.Group.migration_negative,
        try registry.classifyNormalized("tests/persistence/migrations_negative_test.zig"),
    );
    try std.testing.expectError(
        registry.DiscoveryError.UnclassifiedRoot,
        registry.classifyNormalized("tests/persistence/migrations_positive_extra.zig"),
    );
}

test "normalization rejects escapes hidden outputs and non-Zig registrations" {
    const allocator = std.testing.allocator;
    const normalized = try registry.normalizeRootPath(
        allocator,
        "tests\\shared\\money_test.zig",
    );
    defer allocator.free(normalized);
    try std.testing.expectEqualStrings("tests/shared/money_test.zig", normalized);

    try std.testing.expectError(
        registry.DiscoveryError.AbsolutePath,
        registry.normalizeRootPath(allocator, "/synthetic/private/test.zig"),
    );
    try std.testing.expectError(
        registry.DiscoveryError.PathEscape,
        registry.normalizeRootPath(allocator, "tests/../outside.zig"),
    );
    try std.testing.expectError(
        registry.DiscoveryError.HiddenPath,
        registry.normalizeRootPath(allocator, "tests/.cache/hidden.zig"),
    );
    try std.testing.expectError(
        registry.DiscoveryError.HiddenPath,
        registry.normalizeRootPath(allocator, "tests/zig-out/generated.zig"),
    );
    try std.testing.expectError(
        registry.DiscoveryError.NonZigRoot,
        registry.normalizeRootPath(allocator, "tests/shared/vector.json"),
    );
    try std.testing.expectError(
        registry.DiscoveryError.NonUtf8Path,
        registry.normalizeRootPath(allocator, "tests/shared/\xff.zig"),
    );
    try std.testing.expect(std.mem.indexOf(
        u8,
        @errorName(registry.DiscoveryError.AbsolutePath),
        "/synthetic/private",
    ) == null);
}

test "duplicate overlapping symlink and unclassified roots fail closed" {
    const allocator = std.testing.allocator;
    const duplicate = [_]registry.Candidate{
        .{ .path = "tests/shared/money_test.zig" },
        .{ .path = "tests\\shared\\money_test.zig" },
    };
    try std.testing.expectError(
        registry.DiscoveryError.DuplicatePath,
        registry.classifyCandidates(allocator, &duplicate),
    );

    const symlink = [_]registry.Candidate{.{
        .path = "tests/shared/escape_test.zig",
        .kind = .symlink,
    }};
    try std.testing.expectError(
        registry.DiscoveryError.SymlinkRoot,
        registry.classifyCandidates(allocator, &symlink),
    );

    const unclassified = [_]registry.Candidate{.{
        .path = "tests/persistence/unknown_test.zig",
    }};
    try std.testing.expectError(
        registry.DiscoveryError.UnclassifiedRoot,
        registry.classifyCandidates(allocator, &unclassified),
    );

    try std.testing.expectError(
        registry.DiscoveryError.OverlappingRoots,
        registry.validateRoots(&.{ "tests/persistence", "tests/persistence/migrations" }),
    );
    try registry.validateRoots(&.{ "tests/shared", "tests/http", "tests/persistence" });
}

test "producer gates distinguish absent from present but empty" {
    try std.testing.expectError(
        registry.DiscoveryError.MissingProducer,
        registry.validateProducerCounts(.{
            .producer_present = false,
            .required_counts = &.{ 0, 0, 0 },
        }),
    );
    try std.testing.expectError(
        registry.DiscoveryError.IncompleteProducer,
        registry.validateProducerCounts(.{
            .producer_present = true,
            .required_counts = &.{ 1, 0, 1 },
        }),
    );
    try registry.validateProducerCounts(.{
        .producer_present = true,
        .required_counts = &.{ 1, 1, 1 },
    });
}

test "notice validation fails when any acceptance-critical field is absent" {
    const valid =
        \\ShovelerDB GPL-2.0-only
        \\https://github.com/LynnColeArt/ShovelerDB.git
        \\021e3b3d9247a181252329d6ba7ec8d2ed943a97
        \\deps/shovelerdb/LICENSE
    ;
    try std.testing.expect(registry.noticeValid(valid, true));
    try std.testing.expect(!registry.noticeValid(valid, false));
    try std.testing.expect(!registry.noticeValid(
        "ShovelerDB GPL-2.0-only deps/shovelerdb/LICENSE",
        true,
    ));
    try std.testing.expect(!registry.noticeValid(
        "https://github.com/LynnColeArt/ShovelerDB.git GPL-2.0-only deps/shovelerdb/LICENSE",
        true,
    ));
}
