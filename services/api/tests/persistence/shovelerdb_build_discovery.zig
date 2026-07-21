const std = @import("std");
const registry = @import("build_registry");
const coverage = registry.migration_coverage_contract;

fn expectPaths(expected: []const []const u8, actual: []const registry.Classified) !void {
    try std.testing.expectEqual(expected.len, actual.len);
    for (expected, actual) |expected_path, entry| {
        try std.testing.expectEqualStrings(expected_path, entry.path);
    }
}

fn appendCoverageRoot(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    module_name: []const u8,
    declaration_name: []const u8,
    branch_names: []const []const u8,
    declaration_body: []const u8,
) !void {
    try output.print(
        allocator,
        "const std = @import(\"std\");\nconst {s} = @import(\"{s}\");\n" ++
            "test \"{s}\" {{ {s} }}\n",
        .{ module_name, module_name, declaration_name, declaration_body },
    );
    for (branch_names) |branch_name| {
        try output.print(
            allocator,
            "test \"critical branch: {s}\" {{}}\n",
            .{branch_name},
        );
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
        .{ .path = "tests/persistence/migrations_coverage_test.zig" },
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
    try std.testing.expectEqual(
        registry.Group.migration_coverage,
        try registry.classifyNormalized("tests/persistence/migrations_coverage_test.zig"),
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
            .required_counts = &.{ 0, 0, 0, 0 },
        }),
    );
    try std.testing.expectError(
        registry.DiscoveryError.IncompleteProducer,
        registry.validateProducerCounts(.{
            .producer_present = true,
            .required_counts = &.{ 1, 1, 1, 0 },
        }),
    );
    try registry.validateProducerCounts(.{
        .producer_present = true,
        .required_counts = &.{ 1, 1, 1, 1 },
    });
}

test "migration coverage evidence is measured and fails closed" {
    const required = coverage.requiredBranchBits();
    try std.testing.expectError(coverage.CoverageError.MissingMeasurement, coverage.validateMeasurement(.{
        .seen_sites = 0,
        .total_sites = 0,
        .hit_branch_bits = required,
        .required_branch_bits = required,
    }));
    try std.testing.expectError(coverage.CoverageError.IncompleteProductionInstrumentation, coverage.validateMeasurement(.{
        .seen_sites = 1,
        .total_sites = 1,
        .hit_branch_bits = required,
        .required_branch_bits = required,
    }));
    try std.testing.expectError(coverage.CoverageError.BelowThreshold, coverage.validateMeasurement(.{
        .seen_sites = 89,
        .total_sites = 100,
        .hit_branch_bits = required,
        .required_branch_bits = required,
    }));
    try std.testing.expectError(coverage.CoverageError.MissingCriticalBranch, coverage.validateMeasurement(.{
        .seen_sites = 90,
        .total_sites = 100,
        .hit_branch_bits = required & ~@as(u64, 1),
        .required_branch_bits = required,
    }));
    try std.testing.expectError(coverage.CoverageError.InvalidMeasurement, coverage.validateMeasurement(.{
        .seen_sites = 101,
        .total_sites = 100,
        .hit_branch_bits = required,
        .required_branch_bits = required,
    }));
    try coverage.validateMeasurement(.{
        .seen_sites = 90,
        .total_sites = 100,
        .hit_branch_bits = required,
        .required_branch_bits = required,
    });
}

test "migration coverage source and exact critical test contracts reject fabrication" {
    try std.testing.expect(registry.migrationImportsCoverageScoped(
        "const std = @import(\"std\");\n" ++
            "const shared = @import(\"shared\");\n" ++
            "const persistence = @import(\"persistence\");\n" ++
            "const helper = @import(\"migrations_graph.zig\");\n",
    ));
    try std.testing.expect(!registry.migrationImportsCoverageScoped(
        "const store = @import(\"store.zig\");",
    ));
    try std.testing.expect(!registry.migrationImportsCoverageScoped(
        "const hidden = @import(import_name);",
    ));

    const allocator = std.testing.allocator;
    var valid: std.ArrayList(u8) = .empty;
    defer valid.deinit(allocator);
    try valid.appendSlice(
        allocator,
        "const std = @import(\"std\");\n" ++
            "const migrations = @import(\"migrations\");\n" ++
            "test \"migration production declarations are analyzed\" { std.testing.refAllDecls(migrations); }\n",
    );
    for (coverage.critical_branch_names) |branch_name| {
        const declaration = try std.fmt.allocPrint(
            allocator,
            "test \"{s}{s}\" {{}}\n",
            .{ coverage.critical_test_prefix, branch_name },
        );
        defer allocator.free(declaration);
        try valid.appendSlice(allocator, declaration);
    }
    try std.testing.expect(registry.coverageTestContractValid(valid.items));

    try valid.appendSlice(allocator, "test \"critical branch: fabricated\" {}\n");
    try std.testing.expect(!registry.coverageTestContractValid(valid.items));
}

test "coverage roots require executable canonical Zig structure" {
    const allocator = std.testing.allocator;
    var commented: std.ArrayList(u8) = .empty;
    defer commented.deinit(allocator);
    try commented.appendSlice(
        allocator,
        "const std = @import(\"std\");\n" ++
            "const real = @import(\"migrations\");\n" ++
            "const migrations = struct {};\n" ++
            "// std.testing.refAllDecls(migrations);\n" ++
            "const fake = \"std.testing.refAllDecls(migrations);\";\n",
    );
    for (coverage.critical_branch_names) |branch_name| {
        const declaration = try std.fmt.allocPrint(
            allocator,
            "test \"{s}{s}\" {{}}\n",
            .{ coverage.critical_test_prefix, branch_name },
        );
        defer allocator.free(declaration);
        try commented.appendSlice(allocator, declaration);
    }
    try std.testing.expect(!registry.coverageTestContractValid(commented.items));
}

test "all measured scope contracts publish exact denominators and inventories" {
    try std.testing.expectEqual(@as(usize, 24), registry.shared_coverage_contract.minimum_production_sites);
    try std.testing.expectEqual(@as(usize, 24), registry.shared_coverage_contract.critical_branch_count);
    try std.testing.expectEqual(@as(usize, 20), registry.persistence_coverage_contract.minimum_production_sites);
    try std.testing.expectEqual(@as(usize, 20), registry.persistence_coverage_contract.critical_branch_count);
    try std.testing.expectEqual(@as(usize, 36), registry.migration_coverage_contract.minimum_production_sites);
    try std.testing.expectEqual(@as(usize, 36), registry.migration_coverage_contract.critical_branch_count);

    const shared_required = registry.shared_coverage_contract.requiredBranchBits();
    try std.testing.expectError(
        registry.shared_coverage_contract.CoverageError.IncompleteProductionInstrumentation,
        registry.shared_coverage_contract.validateMeasurement(.{
            .seen_sites = 23,
            .total_sites = 23,
            .hit_branch_bits = shared_required,
            .required_branch_bits = shared_required,
        }),
    );
    try std.testing.expectError(
        registry.shared_coverage_contract.CoverageError.MissingCriticalBranch,
        registry.shared_coverage_contract.validateMeasurement(.{
            .seen_sites = 24,
            .total_sites = 24,
            .hit_branch_bits = shared_required & ~@as(u64, 1),
            .required_branch_bits = shared_required,
        }),
    );

    const persistence_required = registry.persistence_coverage_contract.requiredBranchBits();
    try std.testing.expectError(
        registry.persistence_coverage_contract.CoverageError.IncompleteProductionInstrumentation,
        registry.persistence_coverage_contract.validateMeasurement(.{
            .seen_sites = 19,
            .total_sites = 19,
            .hit_branch_bits = persistence_required,
            .required_branch_bits = persistence_required,
        }),
    );
    try std.testing.expectError(
        registry.persistence_coverage_contract.CoverageError.MissingCriticalBranch,
        registry.persistence_coverage_contract.validateMeasurement(.{
            .seen_sites = 20,
            .total_sites = 20,
            .hit_branch_bits = persistence_required & ~@as(u64, 1),
            .required_branch_bits = persistence_required,
        }),
    );
}

test "shared and persistence roots expose only their canonical public module" {
    const allocator = std.testing.allocator;
    var shared: std.ArrayList(u8) = .empty;
    defer shared.deinit(allocator);
    try appendCoverageRoot(
        allocator,
        &shared,
        "shared",
        "shared production declarations are analyzed",
        &registry.shared_coverage_contract.critical_branch_names,
        "std.testing.refAllDecls(shared);",
    );
    try std.testing.expect(registry.sharedCoverageTestContractValid(shared.items));
    try shared.appendSlice(allocator, "const persistence = @import(\"persistence\");\n");
    try std.testing.expect(!registry.sharedCoverageTestContractValid(shared.items));

    var persistence: std.ArrayList(u8) = .empty;
    defer persistence.deinit(allocator);
    try appendCoverageRoot(
        allocator,
        &persistence,
        "persistence",
        "persistence production declarations are analyzed",
        &registry.persistence_coverage_contract.critical_branch_names,
        "std.testing.refAllDecls(persistence);",
    );
    try std.testing.expect(registry.persistenceCoverageTestContractValid(persistence.items));
    try persistence.appendSlice(allocator, "const adapter = @import(\"shovelerdb_adapter\");\n");
    try std.testing.expect(!registry.persistenceCoverageTestContractValid(persistence.items));
}

test "disabled declaration analysis and duplicate bindings fail structurally" {
    const allocator = std.testing.allocator;
    var disabled: std.ArrayList(u8) = .empty;
    defer disabled.deinit(allocator);
    try appendCoverageRoot(
        allocator,
        &disabled,
        "migrations",
        "migration production declarations are analyzed",
        &coverage.critical_branch_names,
        "if (false) std.testing.refAllDecls(migrations);",
    );
    try std.testing.expect(!registry.coverageTestContractValid(disabled.items));

    var duplicate: std.ArrayList(u8) = .empty;
    defer duplicate.deinit(allocator);
    try appendCoverageRoot(
        allocator,
        &duplicate,
        "migrations",
        "migration production declarations are analyzed",
        &coverage.critical_branch_names,
        "std.testing.refAllDecls(migrations);",
    );
    try duplicate.appendSlice(allocator, "const migrations = @import(\"migrations\");\n");
    try std.testing.expect(!registry.coverageTestContractValid(duplicate.items));
}

test "coverage roots cannot mutate probes or sanitizer counters" {
    const allocator = std.testing.allocator;
    var fabricated: std.ArrayList(u8) = .empty;
    defer fabricated.deinit(allocator);
    try appendCoverageRoot(
        allocator,
        &fabricated,
        "migrations",
        "migration production declarations are analyzed",
        &coverage.critical_branch_names,
        "std.testing.refAllDecls(migrations);",
    );
    try fabricated.appendSlice(
        allocator,
        "const counters = @extern([*]u8, .{ .name = \"__start___sancov_cntrs\" });\n",
    );
    try std.testing.expect(!registry.coverageTestContractValid(fabricated.items));
}

test "migration production imports reject normalized traversal and prefix lookalikes" {
    try std.testing.expect(!registry.migrationImportsCoverageScoped(
        "const helper = @import(\"migrations_helpers/../store.zig\");",
    ));
    try std.testing.expect(!registry.migrationImportsCoverageScoped(
        "const helper = @import(\"migrations_lookalike.zig/../../store.zig\");",
    ));
    try std.testing.expect(!registry.migrationImportsCoverageScoped(
        "const helper = @import(\"/migrations_escape.zig\");",
    ));
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
