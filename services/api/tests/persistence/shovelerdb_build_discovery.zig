const std = @import("std");
const registry = @import("build_registry");
const discovery_test_config = @import("discovery_test_config");
const coverage = registry.migration_coverage_contract;

const HttpFixture = struct {
    tmp: std.testing.TmpDir,
    api_path: []u8,

    fn deinit(self: *HttpFixture, allocator: std.mem.Allocator) void {
        allocator.free(self.api_path);
        self.tmp.cleanup();
    }
};

fn writeFixtureFile(dir: std.Io.Dir, path: []const u8, contents: []const u8) !void {
    if (std.fs.path.dirname(path)) |parent_path| {
        var parent = try dir.createDirPathOpen(std.testing.io, parent_path, .{});
        parent.close(std.testing.io);
    }
    var file = try dir.createFile(std.testing.io, path, .{ .truncate = true });
    defer file.close(std.testing.io);
    try file.writeStreamingAll(std.testing.io, contents);
}

fn expectCommandExit(
    allocator: std.mem.Allocator,
    cwd: ?[]const u8,
    argv: []const []const u8,
    expected_code: u8,
) !std.process.RunResult {
    const result = try std.process.run(allocator, std.testing.io, .{
        .argv = argv,
        .cwd = if (cwd) |path| .{ .path = path } else .inherit,
        .stdout_limit = .limited(4 * 1024 * 1024),
        .stderr_limit = .limited(4 * 1024 * 1024),
    });
    errdefer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }
    switch (result.term) {
        .exited => |code| if (code != expected_code) {
            std.debug.print(
                "command exited {d}, expected {d}\nstdout:\n{s}\nstderr:\n{s}\n",
                .{ code, expected_code, result.stdout, result.stderr },
            );
            return error.UnexpectedCommandExit;
        },
        else => {
            std.debug.print(
                "command terminated unexpectedly\nstdout:\n{s}\nstderr:\n{s}\n",
                .{ result.stdout, result.stderr },
            );
            return error.UnexpectedCommandTermination;
        },
    }
    return result;
}

fn expectCommandFailureContaining(
    allocator: std.mem.Allocator,
    cwd: ?[]const u8,
    argv: []const []const u8,
    expected_stderr: []const u8,
) !void {
    const result = try std.process.run(allocator, std.testing.io, .{
        .argv = argv,
        .cwd = if (cwd) |path| .{ .path = path } else .inherit,
        .stdout_limit = .limited(4 * 1024 * 1024),
        .stderr_limit = .limited(4 * 1024 * 1024),
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    switch (result.term) {
        .exited => |code| if (code == 0) {
            std.debug.print(
                "command unexpectedly succeeded; expected stderr containing {s}\nstdout:\n{s}\nstderr:\n{s}\n",
                .{ expected_stderr, result.stdout, result.stderr },
            );
            return error.UnexpectedCommandSuccess;
        },
        else => {
            std.debug.print(
                "command terminated unexpectedly\nstdout:\n{s}\nstderr:\n{s}\n",
                .{ result.stdout, result.stderr },
            );
            return error.UnexpectedCommandTermination;
        },
    }
    if (std.mem.indexOf(u8, result.stderr, expected_stderr) == null) {
        std.debug.print(
            "command failed without expected stderr {s}\nstdout:\n{s}\nstderr:\n{s}\n",
            .{ expected_stderr, result.stdout, result.stderr },
        );
        return error.ExpectedCommandDiagnosticMissing;
    }
}

fn prepareHttpFixture(
    allocator: std.mem.Allocator,
    delay_ms: u64,
    http_test_source: []const u8,
) !HttpFixture {
    var fixture = HttpFixture{
        .tmp = std.testing.tmpDir(.{}),
        .api_path = undefined,
    };
    errdefer fixture.tmp.cleanup();

    var root_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const root_length = try fixture.tmp.dir.realPath(std.testing.io, &root_buffer);
    const root_path = root_buffer[0..root_length];
    fixture.api_path = try std.fs.path.join(allocator, &.{ root_path, "services/api" });
    errdefer allocator.free(fixture.api_path);

    const source_api_path = discovery_test_config.service_root;

    var api_dir = try fixture.tmp.dir.createDirPathOpen(std.testing.io, "services/api", .{});
    api_dir.close(std.testing.io);

    const deps_path = try std.fs.path.join(allocator, &.{ root_path, "deps" });
    defer allocator.free(deps_path);
    const source_deps_path = try std.fs.path.join(allocator, &.{ source_api_path, "../../deps" });
    defer allocator.free(source_deps_path);
    const copy_deps = try expectCommandExit(
        allocator,
        null,
        &.{ "cp", "-a", source_deps_path, deps_path },
        0,
    );
    defer allocator.free(copy_deps.stdout);
    defer allocator.free(copy_deps.stderr);

    const fixture_src = try std.fs.path.join(allocator, &.{ fixture.api_path, "src" });
    defer allocator.free(fixture_src);
    const source_src = try std.fs.path.join(allocator, &.{ source_api_path, "src" });
    defer allocator.free(source_src);
    const copy_src = try expectCommandExit(
        allocator,
        null,
        &.{ "cp", "-a", source_src, fixture_src },
        0,
    );
    defer allocator.free(copy_src.stdout);
    defer allocator.free(copy_src.stderr);

    const fixture_build = try std.fs.path.join(allocator, &.{ fixture.api_path, "build.zig" });
    defer allocator.free(fixture_build);
    const source_build = try std.fs.path.join(allocator, &.{ source_api_path, "build.zig" });
    defer allocator.free(source_build);
    const copy_build = try expectCommandExit(
        allocator,
        null,
        &.{ "cp", source_build, fixture_build },
        0,
    );
    defer allocator.free(copy_build.stdout);
    defer allocator.free(copy_build.stderr);

    const fixture_zon = try std.fs.path.join(allocator, &.{ fixture.api_path, "build.zig.zon" });
    defer allocator.free(fixture_zon);
    const source_zon = try std.fs.path.join(allocator, &.{ source_api_path, "build.zig.zon" });
    defer allocator.free(source_zon);
    const copy_zon = try expectCommandExit(
        allocator,
        null,
        &.{ "cp", source_zon, fixture_zon },
        0,
    );
    defer allocator.free(copy_zon.stdout);
    defer allocator.free(copy_zon.stderr);

    const fixture_notice = try std.fs.path.join(allocator, &.{ root_path, "THIRD_PARTY_NOTICES.md" });
    defer allocator.free(fixture_notice);
    const source_notice = try std.fs.path.join(allocator, &.{ source_api_path, "../../THIRD_PARTY_NOTICES.md" });
    defer allocator.free(source_notice);
    const copy_notice = try expectCommandExit(
        allocator,
        null,
        &.{ "cp", source_notice, fixture_notice },
        0,
    );
    defer allocator.free(copy_notice.stdout);
    defer allocator.free(copy_notice.stderr);

    try writeFixtureFile(
        fixture.tmp.dir,
        "package.json",
        "{\"private\":true,\"scripts\":{\"contracts:generate\":\"node tools/contracts/materialize-fixture.mjs\"}}\n",
    );
    const materializer = try std.fmt.allocPrint(
        allocator,
        "import {{ mkdir, writeFile }} from 'node:fs/promises';\n" ++
            "await new Promise((resolve) => setTimeout(resolve, {d}));\n" ++
            "await mkdir('tools/contracts/.generated/runtime/v1', {{ recursive: true }});\n" ++
            "await writeFile('tools/contracts/.generated/runtime/v1/route-inventory.json', '{{\"routes\":[]}}\\n');\n" ++
            "await writeFile('services/api/tests/http/generated-route-inventory.json', '{{\"routes\":[]}}\\n');\n",
        .{delay_ms},
    );
    defer allocator.free(materializer);
    try writeFixtureFile(
        fixture.tmp.dir,
        "tools/contracts/materialize-fixture.mjs",
        materializer,
    );

    try writeFixtureFile(
        fixture.tmp.dir,
        "services/api/src/shared/root.zig",
        "const probe = @import(\"shared_coverage_probe\");\n" ++
            "pub const marker: u8 = 1;\n" ++
            "pub fn touch() void { _ = probe; }\n",
    );
    try writeFixtureFile(
        fixture.tmp.dir,
        "services/api/src/platform/persistence/root.zig",
        "const adapter = @import(\"shovelerdb_adapter\");\n" ++
            "const shared = @import(\"shared\");\n" ++
            "const probe = @import(\"persistence_coverage_probe\");\n" ++
            "pub const marker = shared.marker;\n" ++
            "pub fn touch() void { _ = adapter; _ = probe; }\n",
    );
    try writeFixtureFile(
        fixture.tmp.dir,
        "services/api/src/platform/persistence/migrations.zig",
        "const adapter = @import(\"shovelerdb_adapter\");\n" ++
            "const shared = @import(\"shared\");\n" ++
            "const persistence = @import(\"persistence\");\n" ++
            "const probe = @import(\"migration_coverage_probe\");\n" ++
            "pub const marker = shared.marker + persistence.marker;\n" ++
            "pub fn touch() void { _ = adapter; _ = probe; }\n",
    );
    try writeFixtureFile(
        fixture.tmp.dir,
        "services/api/src/http/root.zig",
        "const shared = @import(\"shared\");\n" ++
            "pub const marker = shared.marker;\n" ++
            "pub fn touch() void { shared.touch(); }\n",
    );
    try writeFixtureFile(
        fixture.tmp.dir,
        "services/api/src/main.zig",
        "const shared = @import(\"shared\");\n" ++
            "const persistence = @import(\"persistence\");\n" ++
            "const migrations = @import(\"migrations\");\n" ++
            "const http = @import(\"http\");\n" ++
            "pub fn main() !void { shared.touch(); persistence.touch(); migrations.touch(); http.touch(); }\n",
    );
    try writeFixtureFile(
        fixture.tmp.dir,
        "services/api/tests/http/http_fixture_test.zig",
        http_test_source,
    );
    return fixture;
}

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
        "run",
        "coverage",
        "test",
    };
    try std.testing.expectEqual(expected_steps.len, registry.stable_step_names.len);
    for (registry.stable_step_names, 0..) |actual, index| {
        try std.testing.expectEqualStrings(expected_steps[index], actual);
    }
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

test "aggregate invocations are rooted at the canonical repository build file" {
    const invocation = registry.aggregateInvocation("test-http", "-Doptimize=Debug");
    try std.testing.expectEqualStrings("../..", invocation.cwd_from_service_root);
    try std.testing.expectEqualDeep(
        [_][]const u8{
            "zig",
            "build",
            "test-http",
            "-Doptimize=Debug",
            "--build-file",
            "services/api/build.zig",
        },
        invocation.argv,
    );
}

test "isolated HTTP roots compile against the complete service graph and emitted API" {
    const allocator = std.testing.allocator;
    var fixture = try prepareHttpFixture(
        allocator,
        0,
        "const std = @import(\"std\");\n" ++
            "const shared = @import(\"shared\");\n" ++
            "const persistence = @import(\"persistence\");\n" ++
            "const migrations = @import(\"migrations\");\n" ++
            "const http = @import(\"http\");\n" ++
            "const composition = @import(\"composition\");\n" ++
            "const http_test_config = @import(\"http_test_config\");\n" ++
            "test \"public HTTP dependencies compile\" {\n" ++
            "    std.testing.refAllDecls(shared);\n" ++
            "    std.testing.refAllDecls(persistence);\n" ++
            "    std.testing.refAllDecls(migrations);\n" ++
            "    std.testing.refAllDecls(http);\n" ++
            "    std.testing.refAllDecls(composition);\n" ++
            "    try std.testing.expectEqualStrings(\"invoice-manager-api\", std.fs.path.basename(http_test_config.api_executable_path));\n" ++
            "    const result = try std.process.run(std.testing.allocator, std.testing.io, .{ .argv = &.{http_test_config.api_executable_path} });\n" ++
            "    defer std.testing.allocator.free(result.stdout);\n" ++
            "    defer std.testing.allocator.free(result.stderr);\n" ++
            "    switch (result.term) {\n" ++
            "        .exited => |code| try std.testing.expectEqual(@as(u8, 0), code),\n" ++
            "        else => return error.UnexpectedApiTermination,\n" ++
            "    }\n" ++
            "}\n",
    );
    defer fixture.deinit(allocator);

    const result = try expectCommandExit(
        allocator,
        fixture.api_path,
        &.{ "zig", "build", "test-http", "-j16", "--summary", "all" },
        0,
    );
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
}

test "canonical build-file invocation pins emitted API and configured run cwd" {
    const allocator = std.testing.allocator;
    var fixture = try prepareHttpFixture(
        allocator,
        0,
        "const std = @import(\"std\");\n" ++
            "const http_test_config = @import(\"http_test_config\");\n" ++
            "test \"emitted API resolves the canonical migration root\" {\n" ++
            "    const result = try std.process.run(std.testing.allocator, std.testing.io, .{ .argv = &.{http_test_config.api_executable_path} });\n" ++
            "    defer std.testing.allocator.free(result.stdout);\n" ++
            "    defer std.testing.allocator.free(result.stderr);\n" ++
            "    switch (result.term) {\n" ++
            "        .exited => |code| try std.testing.expectEqual(@as(u8, 0), code),\n" ++
            "        else => return error.UnexpectedApiTermination,\n" ++
            "    }\n" ++
            "}\n",
    );
    defer fixture.deinit(allocator);

    try writeFixtureFile(
        fixture.tmp.dir,
        "services/api/migrations/p0/001-canonical-migration.sql",
        "-- canonical repository-root migration sentinel\n",
    );
    try writeFixtureFile(
        fixture.tmp.dir,
        "services/api/src/main.zig",
        "const std = @import(\"std\");\n" ++
            "const shared = @import(\"shared\");\n" ++
            "const persistence = @import(\"persistence\");\n" ++
            "const migrations = @import(\"migrations\");\n" ++
            "const http = @import(\"http\");\n" ++
            "pub fn main(init: std.process.Init) !void {\n" ++
            "    shared.touch(); persistence.touch(); migrations.touch(); http.touch();\n" ++
            "    try std.Io.Dir.cwd().access(init.io, \"services/api/migrations/p0/001-canonical-migration.sql\", .{});\n" ++
            "}\n",
    );

    const services_path = std.fs.path.dirname(fixture.api_path) orelse
        return error.InvalidFixtureApiPath;
    const repository_path = std.fs.path.dirname(services_path) orelse
        return error.InvalidFixtureServicesPath;
    const test_result = try expectCommandExit(
        allocator,
        repository_path,
        &.{
            "zig",
            "build",
            "test-http",
            "-j16",
            "--summary",
            "all",
            "--build-file",
            "services/api/build.zig",
        },
        0,
    );
    defer allocator.free(test_result.stdout);
    defer allocator.free(test_result.stderr);

    const run_result = try expectCommandExit(
        allocator,
        fixture.api_path,
        &.{ "zig", "build", "run", "-j16", "--summary", "all" },
        0,
    );
    defer allocator.free(run_result.stdout);
    defer allocator.free(run_result.stderr);
}

test "production HTTP module cannot import persistence" {
    const allocator = std.testing.allocator;
    var fixture = try prepareHttpFixture(
        allocator,
        0,
        "const std = @import(\"std\");\n" ++
            "const http = @import(\"http\");\n" ++
            "test \"HTTP module declarations compile\" {\n" ++
            "    std.testing.refAllDecls(http);\n" ++
            "}\n",
    );
    defer fixture.deinit(allocator);

    try writeFixtureFile(
        fixture.tmp.dir,
        "services/api/src/http/root.zig",
        "const persistence = @import(\"persistence\");\n" ++
            "pub fn touch() void { persistence.touch(); }\n",
    );
    try expectCommandFailureContaining(
        allocator,
        fixture.api_path,
        &.{ "zig", "build", "test-http", "-j16", "--summary", "all" },
        "no module named 'persistence'",
    );
}

test "HTTP route inventory embeds exact materialized artifact" {
    const allocator = std.testing.allocator;
    var fixture = try prepareHttpFixture(
        allocator,
        1200,
        "const std = @import(\"std\");\n" ++
            "const http = @import(\"http\");\n" ++
            "test \"canonical route inventory bytes are embedded\" {\n" ++
            "    std.testing.refAllDecls(http);\n" ++
            "    try std.testing.expectEqualStrings(\"{\\\"routes\\\":[]}\\n\", http.route_inventory.bytes);\n" ++
            "}\n",
    );
    defer fixture.deinit(allocator);

    try writeFixtureFile(
        fixture.tmp.dir,
        "services/api/src/http/route_inventory.zig",
        "pub const bytes = @embedFile(\"../../../../tools/contracts/.generated/runtime/v1/route-inventory.json\");\n",
    );
    try writeFixtureFile(
        fixture.tmp.dir,
        "services/api/src/http/root.zig",
        "const shared = @import(\"shared\");\n" ++
            "pub const route_inventory = @import(\"route_inventory.zig\");\n" ++
            "pub const marker = shared.marker;\n" ++
            "pub fn touch() void { shared.touch(); _ = route_inventory.bytes; }\n",
    );

    const result = try expectCommandExit(
        allocator,
        fixture.api_path,
        &.{ "zig", "build", "test-http", "-j16", "--summary", "all" },
        0,
    );
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
}

test "HTTP materialization completes before every compile step" {
    const allocator = std.testing.allocator;
    var fixture = try prepareHttpFixture(
        allocator,
        1200,
        "const std = @import(\"std\");\n" ++
            "const inventory = @embedFile(\"generated-route-inventory.json\");\n" ++
            "test \"generated route inventory exists at compile time\" {\n" ++
            "    try std.testing.expect(inventory.len > 0);\n" ++
            "}\n",
    );
    defer fixture.deinit(allocator);

    const result = try expectCommandExit(
        allocator,
        fixture.api_path,
        &.{ "zig", "build", "test-http", "-j16", "--summary", "all" },
        0,
    );
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
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

test "persistence production imports reject undeclared shared dependency" {
    try std.testing.expect(registry.persistenceImportsCoverageScoped(
        "const std = @import(\"std\");\n" ++
            "const adapter = @import(\"shovelerdb_adapter\");\n" ++
            "const probe = @import(\"persistence_coverage_probe\");\n" ++
            "const helper = @import(\"durability.zig\");\n",
    ));
    try std.testing.expect(!registry.persistenceImportsCoverageScoped(
        "const shared = @import(\"shared\");",
    ));
    try std.testing.expect(!registry.persistenceImportsCoverageScoped(
        "const shared = @import(\"../../shared/root.zig\");",
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
