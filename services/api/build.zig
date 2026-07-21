const std = @import("std");
pub const migration_coverage_contract = @import("src/platform/persistence/shovelerdb_coverage_contract.zig");

pub const stable_step_names = [_][]const u8{
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

pub const http_contract_materializer = "npm run contracts:generate";

pub const aggregate_test_order = [_][]const u8{
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

pub const aggregate_coverage_order = [_][]const u8{
    "coverage-shared",
    "coverage-persistence",
    "coverage-migration",
};

pub const Group = enum {
    shovelerdb_integration,
    build_discovery,
    shared,
    persistence_unit,
    persistence_integration,
    persistence_crash,
    migration_unit,
    migration_integration,
    migration_negative,
    migration_coverage,
    http,
};

pub const CandidateKind = enum { regular, symlink, directory, other };

pub const Candidate = struct {
    path: []const u8,
    kind: CandidateKind = .regular,
};

pub const Classified = struct {
    path: []u8,
    group: Group,
};

pub const DiscoveryError = error{
    AbsolutePath,
    PathEscape,
    HiddenPath,
    NonUtf8Path,
    NonZigRoot,
    SymlinkRoot,
    NonRegularRoot,
    DuplicatePath,
    OverlappingRoots,
    UnclassifiedRoot,
    MissingProducer,
    IncompleteProducer,
};

pub const ProducerCounts = struct {
    producer_present: bool,
    required_counts: []const usize,
};

pub fn validateProducerCounts(counts: ProducerCounts) !void {
    if (!counts.producer_present) return DiscoveryError.MissingProducer;
    for (counts.required_counts) |count| {
        if (count == 0) return DiscoveryError.IncompleteProducer;
    }
}

pub fn normalizeRootPath(allocator: std.mem.Allocator, raw: []const u8) ![]u8 {
    if (!std.unicode.utf8ValidateSlice(raw)) return DiscoveryError.NonUtf8Path;
    if (raw.len == 0 or raw[0] == '/' or raw[0] == '\\') return DiscoveryError.AbsolutePath;
    if (raw.len >= 2 and std.ascii.isAlphabetic(raw[0]) and raw[1] == ':') {
        return DiscoveryError.AbsolutePath;
    }

    const normalized = try allocator.dupe(u8, raw);
    errdefer allocator.free(normalized);
    for (normalized) |*byte| {
        if (byte.* == '\\') byte.* = '/';
    }

    var components = std.mem.splitScalar(u8, normalized, '/');
    while (components.next()) |component| {
        if (component.len == 0 or std.mem.eql(u8, component, ".") or std.mem.eql(u8, component, "..")) {
            return DiscoveryError.PathEscape;
        }
        if (component[0] == '.') return DiscoveryError.HiddenPath;
        if (std.mem.eql(u8, component, "zig-cache") or
            std.mem.eql(u8, component, "zig-out") or
            std.mem.eql(u8, component, "node_modules"))
        {
            return DiscoveryError.HiddenPath;
        }
    }
    if (!std.mem.endsWith(u8, normalized, ".zig")) return DiscoveryError.NonZigRoot;
    return normalized;
}

pub fn classifyNormalized(path: []const u8) !Group {
    if (std.mem.eql(u8, path, "tests/persistence/shovelerdb_integration.zig")) {
        return .shovelerdb_integration;
    }
    if (std.mem.eql(u8, path, "tests/persistence/shovelerdb_build_discovery.zig")) {
        return .build_discovery;
    }
    if (std.mem.startsWith(u8, path, "tests/shared/")) return .shared;
    if (std.mem.startsWith(u8, path, "tests/http/")) return .http;

    if (std.mem.startsWith(u8, path, "tests/persistence/")) {
        const basename = std.fs.path.basename(path);
        if (std.mem.eql(u8, basename, "migrations_test.zig")) return .migration_unit;
        if (std.mem.eql(u8, basename, "migrations_integration_test.zig")) return .migration_integration;
        if (std.mem.eql(u8, basename, "migrations_coverage_test.zig")) return .migration_coverage;
        if (std.mem.indexOf(u8, basename, "negative") != null and
            std.mem.startsWith(u8, basename, "migrations"))
        {
            return .migration_negative;
        }

        const persistence_owned = std.mem.startsWith(u8, basename, "store") or
            std.mem.startsWith(u8, basename, "durability") or
            std.mem.startsWith(u8, basename, "directory_sync");
        if (persistence_owned) {
            if (std.mem.indexOf(u8, basename, "_crash") != null) return .persistence_crash;
            if (std.mem.indexOf(u8, basename, "_integration") != null) return .persistence_integration;
            return .persistence_unit;
        }
    }
    return DiscoveryError.UnclassifiedRoot;
}

pub fn classifyCandidates(
    allocator: std.mem.Allocator,
    candidates: []const Candidate,
) ![]Classified {
    const classified = try allocator.alloc(Classified, candidates.len);
    var initialized: usize = 0;
    errdefer {
        for (classified[0..initialized]) |entry| allocator.free(entry.path);
        allocator.free(classified);
    }

    for (candidates) |candidate| {
        switch (candidate.kind) {
            .regular => {},
            .symlink => return DiscoveryError.SymlinkRoot,
            else => return DiscoveryError.NonRegularRoot,
        }
        const normalized = try normalizeRootPath(allocator, candidate.path);
        const group = classifyNormalized(normalized) catch |err| {
            allocator.free(normalized);
            return err;
        };
        classified[initialized] = .{
            .path = normalized,
            .group = group,
        };
        initialized += 1;
    }

    std.mem.sort(Classified, classified, {}, struct {
        fn lessThan(_: void, left: Classified, right: Classified) bool {
            return std.mem.lessThan(u8, left.path, right.path);
        }
    }.lessThan);
    if (classified.len > 1) {
        for (classified[1..], classified[0 .. classified.len - 1]) |current, previous| {
            if (std.mem.eql(u8, current.path, previous.path)) return DiscoveryError.DuplicatePath;
        }
    }
    return classified;
}

pub fn deinitClassified(allocator: std.mem.Allocator, classified: []Classified) void {
    for (classified) |entry| allocator.free(entry.path);
    allocator.free(classified);
}

pub fn validateRoots(roots: []const []const u8) !void {
    for (roots, 0..) |left, left_index| {
        for (roots[left_index + 1 ..]) |right| {
            if (rootContains(left, right) or rootContains(right, left)) {
                return DiscoveryError.OverlappingRoots;
            }
        }
    }
}

fn rootContains(root: []const u8, path: []const u8) bool {
    if (!std.mem.startsWith(u8, path, root)) return false;
    return path.len == root.len or (path.len > root.len and path[root.len] == '/');
}

pub fn noticeValid(notice: []const u8, license_present: bool) bool {
    return license_present and
        std.mem.indexOf(u8, notice, "https://github.com/LynnColeArt/ShovelerDB.git") != null and
        std.mem.indexOf(u8, notice, "021e3b3d9247a181252329d6ba7ec8d2ed943a97") != null and
        std.mem.indexOf(u8, notice, "deps/shovelerdb/LICENSE") != null and
        std.mem.indexOf(u8, notice, "GPL-2.0-only") != null;
}

const Snapshot = struct {
    entries: []Classified,

    fn count(self: Snapshot, group: Group) usize {
        var total: usize = 0;
        for (self.entries) |entry| {
            if (entry.group == group) total += 1;
        }
        return total;
    }
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    requireDependencyFiles(b);
    requireProvenance(b);
    requireNotice(b);
    const snapshot = discoverTests(b) catch |err| {
        std.debug.panic("[test-build-discovery:error] WP04 discovery rejected service roots: {s}", .{@errorName(err)});
    };

    const upstream = b.createModule(.{
        .root_source_file = b.path("../../deps/shovelerdb/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    const abi_root = b.createModule(.{
        .root_source_file = b.path("src/platform/persistence/shovelerdb_abi_root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "shovelerdb_source", .module = upstream }},
    });
    const abi_library = b.addLibrary(.{
        .name = "invoice_manager_shovelerdb_abi",
        .linkage = .static,
        .root_module = abi_root,
    });
    b.installArtifact(abi_library);

    const adapter = createAdapterModule(b, target, optimize, abi_library);
    const adapter_tests = b.addTest(.{
        .name = "shovelerdb-adapter-tests",
        .root_module = adapter,
    });
    const run_adapter = b.addRunArtifact(adapter_tests);
    const adapter_step = b.step("test-shovelerdb-adapter", "Run adapter, lifetime, ABI, and literal tests");
    adapter_step.dependOn(&run_adapter.step);

    const integration_module = b.createModule(.{
        .root_source_file = b.path("tests/persistence/shovelerdb_integration.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "shovelerdb_adapter", .module = adapter }},
    });
    const integration_tests = b.addTest(.{
        .name = "shovelerdb-integration-tests",
        .root_module = integration_module,
    });
    const run_integration = b.addRunArtifact(integration_tests);
    const integration_step = b.step("test-shovelerdb-integration", "Run real filesystem C ABI integration tests");
    integration_step.dependOn(&run_integration.step);

    const registry_module = b.createModule(.{
        .root_source_file = b.path("build.zig"),
        .target = target,
        .optimize = optimize,
    });
    const discovery_module = b.createModule(.{
        .root_source_file = b.path("tests/persistence/shovelerdb_build_discovery.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "build_registry", .module = registry_module }},
    });
    const discovery_tests = b.addTest(.{
        .name = "shovelerdb-build-discovery-tests",
        .root_module = discovery_module,
    });
    const run_discovery = b.addRunArtifact(discovery_tests);
    const discovery_step = b.step("test-build-discovery", "Run deterministic build discovery diagnostics");
    discovery_step.dependOn(&run_discovery.step);

    const shared_step = b.step("test-shared", "Run WP05 shared tests");
    const shared_coverage_step = b.step("coverage-shared", "Run WP05 shared coverage gate");
    configureShared(b, snapshot, target, optimize, shared_step, shared_coverage_step);

    const persistence_step = b.step("test-persistence", "Run WP06 persistence unit tests");
    const persistence_integration_step = b.step("test-persistence-integration", "Run WP06 persistence integration tests");
    const persistence_crash_step = b.step("test-persistence-crash", "Run WP06 persistence crash tests");
    const persistence_coverage_step = b.step("coverage-persistence", "Run WP06 persistence coverage gate");
    configurePersistence(
        b,
        snapshot,
        target,
        optimize,
        abi_library,
        persistence_step,
        persistence_integration_step,
        persistence_crash_step,
        persistence_coverage_step,
    );

    const migration_step = b.step("test-migration", "Run WP07 migration unit tests");
    const migration_integration_step = b.step("test-migration-integration", "Run WP07 migration integration tests");
    const migration_negative_step = b.step("migration-negative", "Run WP07 negative migration matrix");
    const migration_coverage_step = b.step("coverage-migration", "Run WP07 migration coverage and critical branches");
    configureMigration(
        b,
        snapshot,
        target,
        optimize,
        abi_library,
        migration_step,
        migration_integration_step,
        migration_negative_step,
        migration_coverage_step,
    );

    const http_step = b.step("test-http", "Materialize contracts then run WP08 HTTP tests");
    configureHttp(b, snapshot, target, optimize, abi_library, http_step);

    const coverage_step = b.step("coverage", "Aggregate non-vacuous shared, persistence, and migration coverage");
    addSequentialGate(b, coverage_step, &aggregate_coverage_order, optimize);

    const test_step = b.step("test", "Run all service tests in deterministic group order");
    addSequentialGate(b, test_step, &aggregate_test_order, optimize);
}

fn createAdapterModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    abi_library: *std.Build.Step.Compile,
) *std.Build.Module {
    const adapter = b.createModule(.{
        .root_source_file = b.path("src/platform/persistence/shovelerdb.zig"),
        .target = target,
        .optimize = optimize,
    });
    adapter.addIncludePath(b.path("../../deps/shovelerdb/include"));
    adapter.linkLibrary(abi_library);
    return adapter;
}

fn discoverTests(b: *std.Build) !Snapshot {
    const roots = [_][]const u8{ "tests/persistence", "tests/shared", "tests/http" };
    var candidates: std.ArrayList(Candidate) = .empty;

    for (roots) |root| {
        var dir = b.build_root.handle.openDir(b.graph.io, root, .{ .iterate = true, .follow_symlinks = false }) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };
        defer dir.close(b.graph.io);
        var walker = try dir.walk(b.allocator);
        defer walker.deinit();
        while (try walker.next(b.graph.io)) |entry| {
            if (entry.kind == .directory) continue;
            const joined = try std.fmt.allocPrint(b.allocator, "{s}/{s}", .{ root, entry.path });
            const kind: CandidateKind = switch (entry.kind) {
                .file => .regular,
                .sym_link => .symlink,
                else => .other,
            };
            if (!std.mem.endsWith(u8, joined, ".zig") and kind == .regular) continue;
            try candidates.append(b.allocator, .{ .path = joined, .kind = kind });
        }
    }
    return .{ .entries = try classifyCandidates(b.allocator, candidates.items) };
}

fn addGroupTests(
    b: *std.Build,
    snapshot: Snapshot,
    group: Group,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    imports: []const std.Build.Module.Import,
    step: *std.Build.Step,
) void {
    var previous: ?*std.Build.Step = null;
    for (snapshot.entries) |entry| {
        if (entry.group != group) continue;
        const module = b.createModule(.{
            .root_source_file = b.path(entry.path),
            .target = target,
            .optimize = optimize,
            .imports = imports,
        });
        const test_artifact = b.addTest(.{
            .name = b.fmt("{s}-{s}", .{ @tagName(group), std.fs.path.stem(entry.path) }),
            .root_module = module,
        });
        const run = b.addRunArtifact(test_artifact);
        if (previous) |dependency| run.step.dependOn(dependency);
        previous = &run.step;
    }
    if (previous) |last| step.dependOn(last);
}

fn addSequentialGate(
    b: *std.Build,
    aggregate: *std.Build.Step,
    ordered_steps: []const []const u8,
    optimize: std.builtin.OptimizeMode,
) void {
    var previous: ?*std.Build.Step = null;
    const optimize_arg = b.fmt("-Doptimize={s}", .{@tagName(optimize)});
    for (ordered_steps) |step_name| {
        const command = b.addSystemCommand(&.{ "zig", "build", step_name, optimize_arg });
        command.setCwd(b.path("."));
        if (previous) |dependency| command.step.dependOn(dependency);
        previous = &command.step;
    }
    if (previous) |last| aggregate.dependOn(last);
}

fn missingProducer(b: *std.Build, step: *std.Build.Step, message: []const u8) void {
    const fail = b.addFail(message);
    step.dependOn(&fail.step);
}

fn pathExists(b: *std.Build, path: []const u8) bool {
    b.build_root.handle.access(b.graph.io, path, .{}) catch return false;
    return true;
}

fn configureShared(
    b: *std.Build,
    snapshot: Snapshot,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    test_step: *std.Build.Step,
    coverage_step: *std.Build.Step,
) void {
    const producer = pathExists(b, "src/shared") or snapshot.count(.shared) > 0;
    if (!producer) {
        const message = "[test-shared:error] expected tests/shared/*.zig and src/shared/** from owning WP05; observed producer absent, count 0";
        missingProducer(b, test_step, message);
        missingProducer(b, coverage_step, "[coverage-shared:error] expected nonempty WP05 shared roots and critical-branch evidence; observed count 0");
        return;
    }
    if (snapshot.count(.shared) == 0 or !pathExists(b, "src/shared/root.zig")) {
        missingProducer(b, test_step, "[test-shared:error] WP05 producer present but expected src/shared/root.zig and tests/shared/*.zig; observed zero required roots");
        missingProducer(b, coverage_step, "[coverage-shared:error] WP05 producer present but shared coverage inputs are empty");
        return;
    }
    const shared = b.createModule(.{
        .root_source_file = b.path("src/shared/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const imports = [_]std.Build.Module.Import{.{ .name = "shared", .module = shared }};
    addGroupTests(b, snapshot, .shared, target, optimize, &imports, test_step);
    coverage_step.dependOn(test_step);
}

fn configurePersistence(
    b: *std.Build,
    snapshot: Snapshot,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    abi_library: *std.Build.Step.Compile,
    unit_step: *std.Build.Step,
    integration_step: *std.Build.Step,
    crash_step: *std.Build.Step,
    coverage_step: *std.Build.Step,
) void {
    const producer = pathExists(b, "src/platform/persistence/store.zig") or
        pathExists(b, "src/platform/persistence/durability.zig") or
        pathExists(b, "src/platform/persistence/directory_sync.zig") or
        snapshot.count(.persistence_unit) + snapshot.count(.persistence_integration) + snapshot.count(.persistence_crash) > 0;
    if (!producer) {
        missingProducer(b, unit_step, "[test-persistence:error] expected store*/durability*/directory_sync* roots from owning WP06; observed producer absent, count 0");
        missingProducer(b, integration_step, "[test-persistence-integration:error] expected *_integration*.zig from owning WP06; observed producer absent, count 0");
        missingProducer(b, crash_step, "[test-persistence-crash:error] expected *_crash*.zig from owning WP06; observed producer absent, count 0");
        missingProducer(b, coverage_step, "[coverage-persistence:error] expected nonempty WP06 unit/integration/crash roots; observed count 0");
        return;
    }
    if (snapshot.count(.persistence_unit) == 0 or snapshot.count(.persistence_integration) == 0 or snapshot.count(.persistence_crash) == 0) {
        missingProducer(b, unit_step, "[test-persistence:error] WP06 producer present but unit/integration/crash classification is incomplete");
        missingProducer(b, integration_step, "[test-persistence-integration:error] WP06 producer present but expected integration root count is 0");
        missingProducer(b, crash_step, "[test-persistence-crash:error] WP06 producer present but expected crash root count is 0");
        missingProducer(b, coverage_step, "[coverage-persistence:error] WP06 producer present but coverage groups are incomplete");
        return;
    }
    const adapter = createAdapterModule(b, target, optimize, abi_library);
    const imports = [_]std.Build.Module.Import{.{ .name = "shovelerdb_adapter", .module = adapter }};
    addGroupTests(b, snapshot, .persistence_unit, target, optimize, &imports, unit_step);
    addGroupTests(b, snapshot, .persistence_integration, target, optimize, &imports, integration_step);
    addGroupTests(b, snapshot, .persistence_crash, target, optimize, &imports, crash_step);
    coverage_step.dependOn(unit_step);
    coverage_step.dependOn(integration_step);
    coverage_step.dependOn(crash_step);
}

fn configureMigration(
    b: *std.Build,
    snapshot: Snapshot,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    abi_library: *std.Build.Step.Compile,
    unit_step: *std.Build.Step,
    integration_step: *std.Build.Step,
    negative_step: *std.Build.Step,
    coverage_step: *std.Build.Step,
) void {
    const migration_source = "src/platform/persistence/migrations.zig";
    const coverage_test = "tests/persistence/migrations_coverage_test.zig";
    const producer = pathExists(b, "migrations/p0") or pathExists(b, migration_source) or
        snapshot.count(.migration_unit) + snapshot.count(.migration_integration) +
            snapshot.count(.migration_negative) + snapshot.count(.migration_coverage) > 0;
    if (!producer) {
        missingProducer(b, unit_step, "[test-migration:error] expected exact migrations_test.zig and migrations/p0/** from owning WP07; observed producer absent, count 0");
        missingProducer(b, integration_step, "[test-migration-integration:error] expected exact migrations_integration_test.zig from owning WP07; observed producer absent, count 0");
        missingProducer(b, negative_step, "[migration-negative:error] expected nonempty *negative* migration matrix from owning WP07; observed producer absent, count 0");
        missingProducer(b, coverage_step, "[coverage-migration:error] expected migrations.zig, exact migrations_coverage_test.zig, >=90% measured migration logic, and critical-branch execution from owning WP07; observed producer absent, count 0");
        return;
    }
    if (snapshot.count(.migration_unit) != 1 or snapshot.count(.migration_integration) != 1 or
        snapshot.count(.migration_negative) == 0 or snapshot.count(.migration_coverage) != 1 or
        !pathExists(b, "migrations/p0") or !pathExists(b, migration_source) or
        !pathExists(b, "src/shared/root.zig") or !pathExists(b, "src/platform/persistence/root.zig"))
    {
        missingProducer(b, unit_step, "[test-migration:error] WP07 producer present but exact positive unit root or migrations/p0 sentinel is missing/duplicate");
        missingProducer(b, integration_step, "[test-migration-integration:error] WP07 producer present but exact integration root count is not 1");
        missingProducer(b, negative_step, "[migration-negative:error] WP07 producer present but negative root count is 0");
        missingProducer(b, coverage_step, "[coverage-migration:error] WP07 producer present but exact migrations.zig, migrations_coverage_test.zig, WP05/WP06 named module roots, or positive/negative inputs are incomplete");
        return;
    }
    if (!migrationCoverageSourcesValid(b, migration_source, coverage_test)) {
        missingProducer(b, coverage_step, "[coverage-migration:error] WP07 coverage inputs omit the canonical production probe import/hit calls or dedicated test imports the probe directly");
        return;
    }

    const adapter = createAdapterModule(b, target, optimize, abi_library);
    const contract_module = b.createModule(.{
        .root_source_file = b.path("src/platform/persistence/shovelerdb_coverage_contract.zig"),
        .target = target,
        .optimize = .Debug,
        .fuzz = false,
    });
    const probe = b.createModule(.{
        .root_source_file = b.path("src/platform/persistence/shovelerdb_coverage_probe.zig"),
        .target = target,
        .optimize = .Debug,
        .fuzz = false,
        .imports = &.{.{ .name = "migration_coverage_contract", .module = contract_module }},
    });
    const shared = b.createModule(.{
        .root_source_file = b.path("src/shared/root.zig"),
        .target = target,
        .optimize = optimize,
        .fuzz = false,
    });
    const persistence = b.createModule(.{
        .root_source_file = b.path("src/platform/persistence/root.zig"),
        .target = target,
        .optimize = optimize,
        .fuzz = false,
        .imports = &.{
            .{ .name = "shared", .module = shared },
            .{ .name = "shovelerdb_adapter", .module = adapter },
        },
    });
    const migrations = createMigrationModule(
        b,
        migration_source,
        target,
        optimize,
        adapter,
        probe,
        shared,
        persistence,
        false,
    );
    const normal_imports = [_]std.Build.Module.Import{
        .{ .name = "shovelerdb_adapter", .module = adapter },
        .{ .name = "shared", .module = shared },
        .{ .name = "persistence", .module = persistence },
        .{ .name = "migrations", .module = migrations },
    };
    addGroupTests(b, snapshot, .migration_unit, target, optimize, &normal_imports, unit_step);
    addGroupTests(b, snapshot, .migration_integration, target, optimize, &normal_imports, integration_step);
    addGroupTests(b, snapshot, .migration_negative, target, optimize, &normal_imports, negative_step);

    const instrumented_migrations = createMigrationModule(
        b,
        migration_source,
        target,
        .Debug,
        adapter,
        probe,
        shared,
        persistence,
        true,
    );
    const coverage_root = b.createModule(.{
        .root_source_file = b.path(coverage_test),
        .target = target,
        .optimize = .Debug,
        .fuzz = false,
        .imports = &.{
            .{ .name = "migrations", .module = instrumented_migrations },
            .{ .name = "shovelerdb_adapter", .module = adapter },
            .{ .name = "shared", .module = shared },
            .{ .name = "persistence", .module = persistence },
            .{ .name = "migration_coverage_contract", .module = contract_module },
        },
    });
    const coverage_artifact = b.addTest(.{
        .name = "migration-production-coverage",
        .root_module = coverage_root,
        .use_llvm = true,
        .test_runner = .{
            .path = b.path("src/platform/persistence/shovelerdb_coverage_runner.zig"),
            .mode = .simple,
        },
    });
    const run_coverage = b.addRunArtifact(coverage_artifact);
    run_coverage.step.dependOn(unit_step);
    run_coverage.step.dependOn(integration_step);
    run_coverage.step.dependOn(negative_step);
    coverage_step.dependOn(&run_coverage.step);
}

fn createMigrationModule(
    b: *std.Build,
    source: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    adapter: *std.Build.Module,
    probe: *std.Build.Module,
    shared: *std.Build.Module,
    persistence: *std.Build.Module,
    instrumented: bool,
) *std.Build.Module {
    return b.createModule(.{
        .root_source_file = b.path(source),
        .target = target,
        .optimize = optimize,
        .fuzz = instrumented,
        .imports = &.{
            .{ .name = "shovelerdb_adapter", .module = adapter },
            .{ .name = "migration_coverage_probe", .module = probe },
            .{ .name = "shared", .module = shared },
            .{ .name = "persistence", .module = persistence },
        },
    });
}

pub fn migrationCoverageSourcesValid(
    b: *std.Build,
    migration_source: []const u8,
    coverage_test: []const u8,
) bool {
    const root_source = b.build_root.handle.readFileAlloc(
        b.graph.io,
        migration_source,
        b.allocator,
        .limited(4 * 1024 * 1024),
    ) catch return false;
    if (std.mem.indexOf(
        u8,
        root_source,
        "const migration_coverage = @import(\"migration_coverage_probe\");",
    ) == null) return false;

    var hit_found: [migration_coverage_contract.critical_branch_count]bool = @splat(false);
    var dir = b.build_root.handle.openDir(
        b.graph.io,
        "src/platform/persistence",
        .{ .iterate = true, .follow_symlinks = false },
    ) catch return false;
    defer dir.close(b.graph.io);
    var walker = dir.walk(b.allocator) catch return false;
    defer walker.deinit();
    while (walker.next(b.graph.io) catch return false) |entry| {
        if (!std.mem.startsWith(u8, entry.path, "migrations") or
            !std.mem.endsWith(u8, entry.path, ".zig")) continue;
        if (entry.kind != .file) return false;
        const full_path = std.fmt.allocPrint(
            b.allocator,
            "src/platform/persistence/{s}",
            .{entry.path},
        ) catch return false;
        const source = b.build_root.handle.readFileAlloc(
            b.graph.io,
            full_path,
            b.allocator,
            .limited(4 * 1024 * 1024),
        ) catch return false;
        if (!migrationImportsCoverageScoped(source)) return false;
        for (migration_coverage_contract.critical_branch_names, 0..) |branch_name, index| {
            const required_hit = std.fmt.allocPrint(
                b.allocator,
                "migration_coverage.hit(.{s})",
                .{branch_name},
            ) catch return false;
            hit_found[index] = hit_found[index] or std.mem.indexOf(u8, source, required_hit) != null;
        }
    }
    for (hit_found) |found| if (!found) return false;

    const test_source = b.build_root.handle.readFileAlloc(
        b.graph.io,
        coverage_test,
        b.allocator,
        .limited(4 * 1024 * 1024),
    ) catch return false;
    return coverageTestContractValid(test_source);
}

pub fn migrationImportsCoverageScoped(source: []const u8) bool {
    const import_prefix = "@import(\"";
    if (countOccurrences(source, "@import(") != countOccurrences(source, import_prefix)) return false;
    var remaining = source;
    while (std.mem.indexOf(u8, remaining, import_prefix)) |start| {
        const value_start = start + import_prefix.len;
        const after_start = remaining[value_start..];
        const end = std.mem.indexOf(u8, after_start, "\")") orelse return false;
        const value = after_start[0..end];
        const allowed = std.mem.eql(u8, value, "std") or
            std.mem.eql(u8, value, "builtin") or
            std.mem.eql(u8, value, "shovelerdb_adapter") or
            std.mem.eql(u8, value, "migration_coverage_probe") or
            std.mem.eql(u8, value, "shared") or
            std.mem.eql(u8, value, "persistence") or
            (std.mem.startsWith(u8, value, "migrations") and std.mem.endsWith(u8, value, ".zig"));
        if (!allowed) return false;
        remaining = after_start[end + 2 ..];
    }
    return true;
}

pub fn coverageTestContractValid(source: []const u8) bool {
    if (std.mem.indexOf(u8, source, "const std = @import(\"std\");") == null or
        std.mem.indexOf(u8, source, "@import(\"migrations\")") == null or
        std.mem.indexOf(u8, source, "std.testing.refAllDecls(migrations);") == null or
        std.mem.indexOf(u8, source, "migration_coverage_probe") != null or
        std.mem.indexOf(u8, source, "shovelerdb_coverage_probe") != null or
        countOccurrences(source, migration_coverage_contract.critical_test_prefix) !=
            migration_coverage_contract.critical_branch_count)
    {
        return false;
    }
    for (migration_coverage_contract.critical_branch_names) |branch_name| {
        var expected_buffer: [128]u8 = undefined;
        const expected = std.fmt.bufPrint(
            &expected_buffer,
            "test \"{s}{s}\"",
            .{ migration_coverage_contract.critical_test_prefix, branch_name },
        ) catch return false;
        if (countOccurrences(source, expected) != 1) return false;
    }
    return true;
}

fn countOccurrences(haystack: []const u8, needle: []const u8) usize {
    if (needle.len == 0) return 0;
    var count: usize = 0;
    var offset: usize = 0;
    while (std.mem.indexOf(u8, haystack[offset..], needle)) |relative| {
        count += 1;
        offset += relative + needle.len;
    }
    return count;
}

fn configureHttp(
    b: *std.Build,
    snapshot: Snapshot,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    abi_library: *std.Build.Step.Compile,
    test_step: *std.Build.Step,
) void {
    const producer = pathExists(b, "src/main.zig") or pathExists(b, "src/http") or snapshot.count(.http) > 0;
    if (!producer) {
        missingProducer(b, test_step, "[test-http:error] expected src/main.zig, src/http/**, and tests/http/** from owning WP08; observed producer absent, count 0");
        return;
    }
    if (!pathExists(b, "src/main.zig") or !pathExists(b, "src/http/root.zig") or snapshot.count(.http) == 0) {
        missingProducer(b, test_step, "[test-http:error] WP08 producer present but HTTP source/test root set is missing or empty");
        return;
    }

    const materialize = b.addSystemCommand(&.{ "npm", "run", "contracts:generate" });
    materialize.setCwd(b.path("../.."));
    const adapter = createAdapterModule(b, target, optimize, abi_library);
    const imports = [_]std.Build.Module.Import{.{ .name = "shovelerdb_adapter", .module = adapter }};
    addGroupTests(b, snapshot, .http, target, optimize, &imports, test_step);
    test_step.dependOn(&materialize.step);
}

fn requireDependencyFiles(b: *std.Build) void {
    const required = [_][]const u8{
        "../../deps/shovelerdb/PROVENANCE",
        "../../deps/shovelerdb/LICENSE",
        "../../deps/shovelerdb/include/shovelerdb.h",
        "../../deps/shovelerdb/src/lib.zig",
        "../../deps/shovelerdb/src/abi/c_api.zig",
    };
    for (required) |path| {
        if (!pathExists(b, path)) {
            std.debug.panic("[shovelerdb-dependency:error] missing vendored exact-pin path {s}; owning WP04", .{path});
        }
    }
}

fn requireProvenance(b: *std.Build) void {
    const expected_commit = "021e3b3d9247a181252329d6ba7ec8d2ed943a97";
    const expected_tree = "6bb2b4215aa50a8ffbbff3278aea4f32c4fc0f906da817037c44095cfd19480b";
    const expected_license = "240a15a1d0f34d3abca462cdb7e5fb89470967563f16b0e71169e51c1e74cf2b";
    const expected_header = "177535ee08de90ee3f68f708046f19815e283f1072102afb594f6697708f676a";

    const provenance = b.build_root.handle.readFileAlloc(
        b.graph.io,
        "../../deps/shovelerdb/PROVENANCE",
        b.allocator,
        .limited(1024 * 1024),
    ) catch {
        std.debug.panic("[shovelerdb-provenance:error] unable to read exact-pin provenance; owning WP04", .{});
    };
    const required_lines = [_][]const u8{
        "source_url=https://github.com/LynnColeArt/ShovelerDB.git",
        "commit=" ++ expected_commit,
        "abi_version=0.1.0",
        "source_tree_sha256=" ++ expected_tree,
        "source_modifications=none",
    };
    for (required_lines) |line| {
        if (std.mem.indexOf(u8, provenance, line) == null) {
            std.debug.panic("[shovelerdb-provenance:error] missing or changed required field {s}; owning WP04", .{line});
        }
    }

    const actual_tree = sourceTreeDigest(b) catch |err| {
        std.debug.panic("[shovelerdb-provenance:error] source-tree verification failed: {s}; owning WP04", .{@errorName(err)});
    };
    if (!std.mem.eql(u8, &actual_tree, expected_tree)) {
        std.debug.panic("[shovelerdb-provenance:error] vendored source digest differs from the exact public export; owning WP04", .{});
    }

    const actual_license = fileDigest(b, "../../deps/shovelerdb/LICENSE") catch |err| {
        std.debug.panic("[license:error] unable to hash preserved ShovelerDB LICENSE: {s}; owning WP04", .{@errorName(err)});
    };
    if (!std.mem.eql(u8, &actual_license, expected_license)) {
        std.debug.panic("[license:error] preserved ShovelerDB LICENSE differs from exact public commit; owning WP04", .{});
    }
    const actual_header = fileDigest(b, "../../deps/shovelerdb/include/shovelerdb.h") catch |err| {
        std.debug.panic("[shovelerdb-provenance:error] unable to hash ABI header: {s}; owning WP04", .{@errorName(err)});
    };
    if (!std.mem.eql(u8, &actual_header, expected_header)) {
        std.debug.panic("[shovelerdb-provenance:error] shovelerdb.h differs from exact public commit; owning WP04", .{});
    }
}

fn sourceTreeDigest(b: *std.Build) ![64]u8 {
    var source_dir = try b.build_root.handle.openDir(
        b.graph.io,
        "../../deps/shovelerdb",
        .{ .iterate = true, .follow_symlinks = false },
    );
    defer source_dir.close(b.graph.io);

    var paths: std.ArrayList([]const u8) = .empty;
    var walker = try source_dir.walk(b.allocator);
    defer walker.deinit();
    while (try walker.next(b.graph.io)) |entry| {
        const included = std.mem.eql(u8, entry.path, "LICENSE") or
            std.mem.startsWith(u8, entry.path, "include/") or
            std.mem.startsWith(u8, entry.path, "src/");
        if (!included) continue;
        if (entry.kind == .directory) continue;
        if (entry.kind != .file) return error.NonRegularSource;
        try paths.append(b.allocator, try b.allocator.dupe(u8, entry.path));
    }
    std.mem.sort([]const u8, paths.items, {}, struct {
        fn lessThan(_: void, left: []const u8, right: []const u8) bool {
            return std.mem.lessThan(u8, left, right);
        }
    }.lessThan);

    var aggregate = std.crypto.hash.sha2.Sha256.init(.{});
    for (paths.items) |path| {
        const full_path = try std.fmt.allocPrint(b.allocator, "../../deps/shovelerdb/{s}", .{path});
        const contents = try b.build_root.handle.readFileAlloc(
            b.graph.io,
            full_path,
            b.allocator,
            .limited(16 * 1024 * 1024),
        );
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(contents, &digest, .{});
        const hex = std.fmt.bytesToHex(digest, .lower);
        aggregate.update(&hex);
        aggregate.update("  ");
        aggregate.update(path);
        aggregate.update("\n");
    }
    var result: [32]u8 = undefined;
    aggregate.final(&result);
    return std.fmt.bytesToHex(result, .lower);
}

fn fileDigest(b: *std.Build, path: []const u8) ![64]u8 {
    const contents = try b.build_root.handle.readFileAlloc(
        b.graph.io,
        path,
        b.allocator,
        .limited(16 * 1024 * 1024),
    );
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(contents, &digest, .{});
    return std.fmt.bytesToHex(digest, .lower);
}

fn requireNotice(b: *std.Build) void {
    const notice = b.build_root.handle.readFileAlloc(
        b.graph.io,
        "../../THIRD_PARTY_NOTICES.md",
        b.allocator,
        .limited(1024 * 1024),
    ) catch {
        std.debug.panic("[license:error] missing THIRD_PARTY_NOTICES.md; owning WP04", .{});
    };
    if (!noticeValid(notice, pathExists(b, "../../deps/shovelerdb/LICENSE"))) {
        std.debug.panic("[license:error] ShovelerDB notice must include public URL, exact commit, GPL-2.0-only, and deps/shovelerdb/LICENSE; owning WP04", .{});
    }
}
