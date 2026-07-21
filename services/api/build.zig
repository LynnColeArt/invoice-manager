const std = @import("std");
pub const migration_coverage_contract = @import("src/platform/persistence/shovelerdb_coverage_contract.zig");
pub const shared_coverage_contract = @import("src/platform/persistence/shovelerdb_shared_coverage_contract.zig");
pub const persistence_coverage_contract = @import("src/platform/persistence/shovelerdb_persistence_coverage_contract.zig");

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
    "run",
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

    fn hasPath(self: Snapshot, path: []const u8) bool {
        for (self.entries) |entry| {
            if (std.mem.eql(u8, entry.path, path)) return true;
        }
        return false;
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
    const run_step = b.step("run", "Materialize contracts then run the WP08 API service");
    configureHttp(b, snapshot, target, optimize, abi_library, http_step, run_step);

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
        // The adapter is an uninstrumented dependency of each domain coverage
        // module. Leaving this unspecified inherits `.fuzz = true` from an
        // instrumented importer and contaminates the domain PC denominator.
        .fuzz = false,
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
    addGroupTestsAfter(b, snapshot, group, target, optimize, imports, null, step);
}

fn addGroupTestsAfter(
    b: *std.Build,
    snapshot: Snapshot,
    group: Group,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    imports: []const std.Build.Module.Import,
    compile_prerequisite: ?*std.Build.Step,
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
        if (compile_prerequisite) |prerequisite| {
            test_artifact.step.dependOn(prerequisite);
        }
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

fn readSource(b: *std.Build, path: []const u8) ?[]const u8 {
    return b.build_root.handle.readFileAlloc(
        b.graph.io,
        path,
        b.allocator,
        .limited(4 * 1024 * 1024),
    ) catch null;
}

fn createCoverageProbeModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    source: []const u8,
) *std.Build.Module {
    return b.createModule(.{
        .root_source_file = b.path(source),
        .target = target,
        .optimize = .Debug,
        .fuzz = false,
    });
}

fn createSharedModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    probe: *std.Build.Module,
    instrumented: bool,
) *std.Build.Module {
    return b.createModule(.{
        .root_source_file = b.path("src/shared/root.zig"),
        .target = target,
        .optimize = optimize,
        .fuzz = instrumented,
        .imports = &.{.{ .name = "shared_coverage_probe", .module = probe }},
    });
}

fn createPersistenceModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    adapter: *std.Build.Module,
    shared: ?*std.Build.Module,
    probe: *std.Build.Module,
    instrumented: bool,
) *std.Build.Module {
    if (shared) |shared_module| {
        return b.createModule(.{
            .root_source_file = b.path("src/platform/persistence/root.zig"),
            .target = target,
            .optimize = optimize,
            .fuzz = instrumented,
            .imports = &.{
                .{ .name = "shovelerdb_adapter", .module = adapter },
                .{ .name = "shared", .module = shared_module },
                .{ .name = "persistence_coverage_probe", .module = probe },
            },
        });
    }
    return b.createModule(.{
        .root_source_file = b.path("src/platform/persistence/root.zig"),
        .target = target,
        .optimize = optimize,
        .fuzz = instrumented,
        .imports = &.{
            .{ .name = "shovelerdb_adapter", .module = adapter },
            .{ .name = "persistence_coverage_probe", .module = probe },
        },
    });
}

fn addCoverageArtifact(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    coverage_test: []const u8,
    public_module_name: []const u8,
    instrumented_module: *std.Build.Module,
    artifact_name: []const u8,
    runner_path: []const u8,
    ordinary_dependencies: []const *std.Build.Step,
    coverage_step: *std.Build.Step,
) void {
    const coverage_root = b.createModule(.{
        .root_source_file = b.path(coverage_test),
        .target = target,
        .optimize = .Debug,
        .fuzz = false,
        .imports = &.{.{ .name = public_module_name, .module = instrumented_module }},
    });
    const coverage_artifact = b.addTest(.{
        .name = artifact_name,
        .root_module = coverage_root,
        .use_llvm = true,
        .test_runner = .{
            .path = b.path(runner_path),
            .mode = .simple,
        },
    });
    const run_coverage = b.addRunArtifact(coverage_artifact);
    for (ordinary_dependencies) |dependency| run_coverage.step.dependOn(dependency);
    coverage_step.dependOn(&run_coverage.step);
}

fn configureShared(
    b: *std.Build,
    snapshot: Snapshot,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    test_step: *std.Build.Step,
    coverage_step: *std.Build.Step,
) void {
    const coverage_test = "tests/shared/boundary_coverage_test.zig";
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
    const probe = createCoverageProbeModule(
        b,
        target,
        "src/platform/persistence/shovelerdb_shared_coverage_probe.zig",
    );
    const shared = createSharedModule(b, target, optimize, probe, false);
    const imports = [_]std.Build.Module.Import{.{ .name = "shared", .module = shared }};
    addGroupTests(b, snapshot, .shared, target, optimize, &imports, test_step);
    if (!snapshot.hasPath(coverage_test) or !coverageScopeSourcesValid(b, .shared) or
        !coverageRootContractValid(
            b.allocator,
            readSource(b, coverage_test) orelse "",
            "shared",
            "shared production declarations are analyzed",
            &shared_coverage_contract.critical_branch_names,
        ))
    {
        missingProducer(b, coverage_step, "[coverage-shared:error] exact boundary_coverage_test.zig, canonical shared module structure, scoped production imports, 24 exact probes, or executable declaration analysis is missing");
        return;
    }
    const instrumented_shared = createSharedModule(b, target, .Debug, probe, true);
    addCoverageArtifact(
        b,
        target,
        coverage_test,
        "shared",
        instrumented_shared,
        "shared-production-coverage",
        "src/platform/persistence/shovelerdb_shared_coverage_runner.zig",
        &.{test_step},
        coverage_step,
    );
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
    const coverage_test = "tests/persistence/durability_coverage_test.zig";
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
    if (snapshot.count(.persistence_unit) == 0 or snapshot.count(.persistence_integration) == 0 or snapshot.count(.persistence_crash) == 0 or
        !pathExists(b, "src/platform/persistence/root.zig"))
    {
        missingProducer(b, unit_step, "[test-persistence:error] WP06 producer present but unit/integration/crash classification is incomplete");
        missingProducer(b, integration_step, "[test-persistence-integration:error] WP06 producer present but expected integration root count is 0");
        missingProducer(b, crash_step, "[test-persistence-crash:error] WP06 producer present but expected crash root count is 0");
        missingProducer(b, coverage_step, "[coverage-persistence:error] WP06 producer present but coverage groups are incomplete");
        return;
    }
    const adapter = createAdapterModule(b, target, optimize, abi_library);
    const persistence_probe = createCoverageProbeModule(
        b,
        target,
        "src/platform/persistence/shovelerdb_persistence_coverage_probe.zig",
    );
    const persistence = createPersistenceModule(
        b,
        target,
        optimize,
        adapter,
        null,
        persistence_probe,
        false,
    );
    const imports = [_]std.Build.Module.Import{.{ .name = "persistence", .module = persistence }};
    addGroupTests(b, snapshot, .persistence_unit, target, optimize, &imports, unit_step);
    addGroupTests(b, snapshot, .persistence_integration, target, optimize, &imports, integration_step);
    addGroupTests(b, snapshot, .persistence_crash, target, optimize, &imports, crash_step);
    if (!snapshot.hasPath(coverage_test) or !coverageScopeSourcesValid(b, .persistence) or
        !coverageRootContractValid(
            b.allocator,
            readSource(b, coverage_test) orelse "",
            "persistence",
            "persistence production declarations are analyzed",
            &persistence_coverage_contract.critical_branch_names,
        ))
    {
        missingProducer(b, coverage_step, "[coverage-persistence:error] exact durability_coverage_test.zig, canonical persistence module structure, scoped production imports, 20 exact probes, or executable declaration analysis is missing");
        return;
    }
    const instrumented_persistence = createPersistenceModule(
        b,
        target,
        .Debug,
        adapter,
        null,
        persistence_probe,
        true,
    );
    addCoverageArtifact(
        b,
        target,
        coverage_test,
        "persistence",
        instrumented_persistence,
        "persistence-production-coverage",
        "src/platform/persistence/shovelerdb_persistence_coverage_runner.zig",
        &.{ unit_step, integration_step, crash_step },
        coverage_step,
    );
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
    const adapter = createAdapterModule(b, target, optimize, abi_library);
    const probe = createCoverageProbeModule(
        b,
        target,
        "src/platform/persistence/shovelerdb_coverage_probe.zig",
    );
    const shared_probe = createCoverageProbeModule(
        b,
        target,
        "src/platform/persistence/shovelerdb_shared_coverage_probe.zig",
    );
    const shared = createSharedModule(b, target, optimize, shared_probe, false);
    const persistence_probe = createCoverageProbeModule(
        b,
        target,
        "src/platform/persistence/shovelerdb_persistence_coverage_probe.zig",
    );
    const persistence = createPersistenceModule(
        b,
        target,
        optimize,
        adapter,
        shared,
        persistence_probe,
        false,
    );
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

    if (!migrationCoverageSourcesValid(b, migration_source, coverage_test)) {
        missingProducer(b, coverage_step, "[coverage-migration:error] WP07 coverage inputs omit canonical Zig module/declaration structure, scoped production imports, exact production probe hits, or the dedicated coverage root");
        return;
    }

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
    addCoverageArtifact(
        b,
        target,
        coverage_test,
        "migrations",
        instrumented_migrations,
        "migration-production-coverage",
        "src/platform/persistence/shovelerdb_coverage_runner.zig",
        &.{ unit_step, integration_step, negative_step },
        coverage_step,
    );
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
    _: []const u8,
    coverage_test: []const u8,
) bool {
    const test_source = readSource(b, coverage_test) orelse return false;
    return coverageScopeSourcesValid(b, .migration) and coverageRootContractValid(
        b.allocator,
        test_source,
        "migrations",
        "migration production declarations are analyzed",
        &migration_coverage_contract.critical_branch_names,
    );
}

pub fn migrationImportsCoverageScoped(source: []const u8) bool {
    const named = [_][]const u8{
        "std",
        "builtin",
        "shovelerdb_adapter",
        "migration_coverage_probe",
        "shared",
        "persistence",
    };
    return importsLexicallyScoped(std.heap.page_allocator, source, &named, "migrations");
}

pub fn coverageTestContractValid(source: []const u8) bool {
    return coverageRootContractValid(
        std.heap.page_allocator,
        source,
        "migrations",
        "migration production declarations are analyzed",
        &migration_coverage_contract.critical_branch_names,
    );
}

pub fn sharedCoverageTestContractValid(source: []const u8) bool {
    return coverageRootContractValid(
        std.heap.page_allocator,
        source,
        "shared",
        "shared production declarations are analyzed",
        &shared_coverage_contract.critical_branch_names,
    );
}

pub fn persistenceCoverageTestContractValid(source: []const u8) bool {
    return coverageRootContractValid(
        std.heap.page_allocator,
        source,
        "persistence",
        "persistence production declarations are analyzed",
        &persistence_coverage_contract.critical_branch_names,
    );
}

pub fn persistenceImportsCoverageScoped(source: []const u8) bool {
    const named = [_][]const u8{
        "std",
        "builtin",
        "shovelerdb_adapter",
        "persistence_coverage_probe",
    };
    return importsLexicallyScoped(std.heap.page_allocator, source, &named, "");
}

const CoverageScope = enum { shared, persistence, migration };

fn coverageScopeSourcesValid(b: *std.Build, scope: CoverageScope) bool {
    const directory = switch (scope) {
        .shared => "src/shared",
        .persistence, .migration => "src/platform/persistence",
    };
    const root_path = switch (scope) {
        .shared => "src/shared/root.zig",
        .persistence => "src/platform/persistence/root.zig",
        .migration => "src/platform/persistence/migrations.zig",
    };
    const probe_module = switch (scope) {
        .shared => "shared_coverage_probe",
        .persistence => "persistence_coverage_probe",
        .migration => "migration_coverage_probe",
    };
    const probe_binding = switch (scope) {
        .shared => "shared_coverage",
        .persistence => "persistence_coverage",
        .migration => "migration_coverage",
    };
    const branch_names: []const []const u8 = switch (scope) {
        .shared => &shared_coverage_contract.critical_branch_names,
        .persistence => &persistence_coverage_contract.critical_branch_names,
        .migration => &migration_coverage_contract.critical_branch_names,
    };
    const named_imports: []const []const u8 = switch (scope) {
        .shared => &.{ "std", "builtin", "shared_coverage_probe" },
        .persistence => &.{ "std", "builtin", "shovelerdb_adapter", "persistence_coverage_probe" },
        .migration => &.{ "std", "builtin", "shared", "persistence", "shovelerdb_adapter", "migration_coverage_probe" },
    };

    var dir = b.build_root.handle.openDir(
        b.graph.io,
        directory,
        .{ .iterate = true, .follow_symlinks = false },
    ) catch return false;
    defer dir.close(b.graph.io);
    var walker = dir.walk(b.allocator) catch return false;
    defer walker.deinit();
    var files: std.ArrayList([]const u8) = .empty;
    while (walker.next(b.graph.io) catch return false) |entry| {
        if (!scopeOwnsSource(scope, entry.path)) continue;
        if (entry.kind != .file) return false;
        const full_path = std.fmt.allocPrint(b.allocator, "{s}/{s}", .{ directory, entry.path }) catch return false;
        files.append(b.allocator, full_path) catch return false;
    }
    std.mem.sort([]const u8, files.items, {}, struct {
        fn lessThan(_: void, left: []const u8, right: []const u8) bool {
            return std.mem.lessThan(u8, left, right);
        }
    }.lessThan);
    if (!sliceContains(files.items, root_path)) return false;

    const hit_found = b.allocator.alloc(bool, branch_names.len) catch return false;
    @memset(hit_found, false);
    for (files.items) |path| {
        const source = readSource(b, path) orelse return false;
        if (!productionSourceValid(
            b.allocator,
            source,
            path,
            files.items,
            named_imports,
            probe_module,
            probe_binding,
            branch_names,
            hit_found,
        )) return false;
    }
    for (hit_found) |found| if (!found) return false;
    return true;
}

fn scopeOwnsSource(scope: CoverageScope, relative_path: []const u8) bool {
    if (!std.mem.endsWith(u8, relative_path, ".zig")) return false;
    return switch (scope) {
        .shared => true,
        .persistence => blk: {
            if (std.mem.indexOfScalar(u8, relative_path, '/') != null) break :blk false;
            break :blk std.mem.eql(u8, relative_path, "root.zig") or
                std.mem.startsWith(u8, relative_path, "store") or
                std.mem.startsWith(u8, relative_path, "durability") or
                std.mem.startsWith(u8, relative_path, "directory_sync") or
                std.mem.startsWith(u8, relative_path, "diagnostic");
        },
        .migration => std.mem.indexOfScalar(u8, relative_path, '/') == null and
            std.mem.startsWith(u8, relative_path, "migrations"),
    };
}

fn productionSourceValid(
    allocator: std.mem.Allocator,
    source: []const u8,
    source_path: []const u8,
    scope_files: []const []const u8,
    named_imports: []const []const u8,
    probe_module: []const u8,
    probe_binding: []const u8,
    branch_names: []const []const u8,
    hit_found: []bool,
) bool {
    var parsed = ParsedSource.init(allocator, source) orelse return false;
    defer parsed.deinit(allocator);
    const tree = &parsed.tree;
    const probe_decl = canonicalBinding(tree, probe_binding, probe_module);
    if (!probe_decl.valid) return false;

    var probe_imports: usize = 0;
    var probe_calls: usize = 0;
    var i: usize = 0;
    while (i < tree.tokens.len) : (i += 1) {
        const token: std.zig.Ast.TokenIndex = @intCast(i);
        const tag = tree.tokenTag(token);
        if (tag == .builtin and (std.mem.eql(u8, tree.tokenSlice(token), "@extern") or
            std.mem.eql(u8, tree.tokenSlice(token), "@export") or
            std.mem.eql(u8, tree.tokenSlice(token), "@disableInstrumentation") or
            std.mem.eql(u8, tree.tokenSlice(token), "@ptrFromInt"))) return false;
        if ((tag == .identifier or tag == .string_literal) and
            (std.mem.indexOf(u8, tree.tokenSlice(token), "__sancov") != null or
                std.mem.indexOf(u8, tree.tokenSlice(token), "invoice_manager_shared_coverage") != null or
                std.mem.indexOf(u8, tree.tokenSlice(token), "invoice_manager_persistence_coverage") != null or
                std.mem.indexOf(u8, tree.tokenSlice(token), "invoice_manager_migration_coverage") != null)) return false;
        if ((tag == .keyword_const or tag == .keyword_var) and i + 1 < tree.tokens.len and
            tree.tokenTag(@intCast(i + 1)) == .identifier and
            std.mem.eql(u8, tree.tokenSlice(@intCast(i + 1)), probe_binding) and
            (probe_decl.token == null or probe_decl.token.? != token)) return false;
        if (tag == .builtin and std.mem.eql(u8, tree.tokenSlice(token), "@import")) {
            const imported = importValue(tree, i) orelse return false;
            if (std.mem.eql(u8, imported, probe_module)) {
                probe_imports += 1;
                if (probe_decl.token == null or i != @as(usize, probe_decl.token.?) + 3) return false;
            }
            if (!sliceContains(named_imports, imported) and
                !relativeImportResolves(source_path, imported, scope_files)) return false;
        }
        if (tag == .identifier and std.mem.eql(u8, tree.tokenSlice(token), probe_binding) and
            tokenSequence(tree, i, &.{ .identifier, .period, .identifier, .l_paren, .period, .identifier, .r_paren }) and
            std.mem.eql(u8, tree.tokenSlice(@intCast(i + 2)), "hit"))
        {
            const branch_name = tree.tokenSlice(@intCast(i + 5));
            const branch_index = indexOf(branch_names, branch_name) orelse return false;
            hit_found[branch_index] = true;
            probe_calls += 1;
        }
    }
    if (probe_calls == 0) return probe_imports == 0 and probe_decl.token == null;
    return probe_imports == 1 and probe_decl.token != null;
}

fn coverageRootContractValid(
    allocator: std.mem.Allocator,
    source: []const u8,
    module_name: []const u8,
    declaration_test_name: []const u8,
    branch_names: []const []const u8,
) bool {
    var parsed = ParsedSource.init(allocator, source) orelse return false;
    defer parsed.deinit(allocator);
    const tree = &parsed.tree;
    const std_decl = canonicalBinding(tree, "std", "std");
    const module_decl = canonicalBinding(tree, module_name, module_name);
    if (!std_decl.valid or !module_decl.valid or std_decl.token == null or module_decl.token == null) return false;

    var std_imports: usize = 0;
    var module_imports: usize = 0;
    var i: usize = 0;
    while (i < tree.tokens.len) : (i += 1) {
        const token: std.zig.Ast.TokenIndex = @intCast(i);
        const tag = tree.tokenTag(token);
        if (tag == .builtin and (std.mem.eql(u8, tree.tokenSlice(token), "@extern") or
            std.mem.eql(u8, tree.tokenSlice(token), "@export") or
            std.mem.eql(u8, tree.tokenSlice(token), "@disableInstrumentation") or
            std.mem.eql(u8, tree.tokenSlice(token), "@ptrFromInt"))) return false;
        if ((tag == .identifier or tag == .string_literal) and
            (std.mem.indexOf(u8, tree.tokenSlice(token), "__sancov") != null or
                std.mem.indexOf(u8, tree.tokenSlice(token), "invoice_manager_shared_coverage") != null or
                std.mem.indexOf(u8, tree.tokenSlice(token), "invoice_manager_persistence_coverage") != null or
                std.mem.indexOf(u8, tree.tokenSlice(token), "invoice_manager_migration_coverage") != null)) return false;
        if ((tag == .keyword_const or tag == .keyword_var) and i + 1 < tree.tokens.len and
            tree.tokenTag(@intCast(i + 1)) == .identifier)
        {
            const name = tree.tokenSlice(@intCast(i + 1));
            if (std.mem.eql(u8, name, "std") and token != std_decl.token.?) return false;
            if (std.mem.eql(u8, name, module_name) and token != module_decl.token.?) return false;
        }
        if (tag == .builtin and std.mem.eql(u8, tree.tokenSlice(token), "@import")) {
            const imported = importValue(tree, i) orelse return false;
            if (std.mem.eql(u8, imported, "std")) {
                std_imports += 1;
                if (i != @as(usize, std_decl.token.?) + 3) return false;
            } else if (std.mem.eql(u8, imported, module_name)) {
                module_imports += 1;
                if (i != @as(usize, module_decl.token.?) + 3) return false;
            } else return false;
        }
    }
    if (std_imports != 1 or module_imports != 1) return false;

    const critical_seen = allocator.alloc(bool, branch_names.len) catch return false;
    defer allocator.free(critical_seen);
    @memset(critical_seen, false);
    var declaration_tests: usize = 0;
    for (tree.rootDecls()) |node| {
        if (tree.nodeTag(node) != .test_decl) continue;
        const name_token = tree.nodeData(node).opt_token_and_node[0].unwrap() orelse continue;
        const name = stringLiteralValue(tree.tokenSlice(name_token)) orelse return false;
        if (std.mem.eql(u8, name, declaration_test_name)) {
            declaration_tests += 1;
            if (!declarationTestExact(tree, node, module_name)) return false;
            continue;
        }
        if (!std.mem.startsWith(u8, name, migration_coverage_contract.critical_test_prefix)) continue;
        const branch_name = name[migration_coverage_contract.critical_test_prefix.len..];
        const branch_index = indexOf(branch_names, branch_name) orelse return false;
        if (critical_seen[branch_index]) return false;
        critical_seen[branch_index] = true;
    }
    if (declaration_tests != 1) return false;
    for (critical_seen) |seen| if (!seen) return false;
    return true;
}

const BindingResult = struct {
    token: ?std.zig.Ast.TokenIndex = null,
    valid: bool = true,
};

fn canonicalBinding(tree: *const std.zig.Ast, binding: []const u8, module_name: []const u8) BindingResult {
    var result: BindingResult = .{};
    for (tree.rootDecls()) |node| {
        if (!bindingDeclExact(tree, node, binding, module_name)) continue;
        if (result.token != null) return .{ .valid = false };
        result.token = tree.firstToken(node);
    }
    return result;
}

fn bindingDeclExact(
    tree: *const std.zig.Ast,
    node: std.zig.Ast.Node.Index,
    binding: []const u8,
    module_name: []const u8,
) bool {
    const first = tree.firstToken(node);
    const last = tree.lastToken(node);
    if (@as(usize, last) != @as(usize, first) + 6) return false;
    if (!tokenSequence(tree, first, &.{ .keyword_const, .identifier, .equal, .builtin, .l_paren, .string_literal, .r_paren })) return false;
    return std.mem.eql(u8, tree.tokenSlice(first + 1), binding) and
        std.mem.eql(u8, tree.tokenSlice(first + 3), "@import") and
        std.mem.eql(u8, stringLiteralValue(tree.tokenSlice(first + 5)) orelse return false, module_name);
}

fn declarationTestExact(
    tree: *const std.zig.Ast,
    node: std.zig.Ast.Node.Index,
    module_name: []const u8,
) bool {
    const first = tree.firstToken(node);
    const last = tree.lastToken(node);
    if (@as(usize, last) != @as(usize, first) + 12) return false;
    if (!tokenSequence(tree, first, &.{
        .keyword_test,
        .string_literal,
        .l_brace,
        .identifier,
        .period,
        .identifier,
        .period,
        .identifier,
        .l_paren,
        .identifier,
        .r_paren,
        .semicolon,
        .r_brace,
    })) return false;
    return std.mem.eql(u8, tree.tokenSlice(first + 3), "std") and
        std.mem.eql(u8, tree.tokenSlice(first + 5), "testing") and
        std.mem.eql(u8, tree.tokenSlice(first + 7), "refAllDecls") and
        std.mem.eql(u8, tree.tokenSlice(first + 9), module_name);
}

fn importsLexicallyScoped(
    allocator: std.mem.Allocator,
    source: []const u8,
    named_imports: []const []const u8,
    relative_prefix: []const u8,
) bool {
    var parsed = ParsedSource.init(allocator, source) orelse return false;
    defer parsed.deinit(allocator);
    const tree = &parsed.tree;
    var i: usize = 0;
    while (i < tree.tokens.len) : (i += 1) {
        const token: std.zig.Ast.TokenIndex = @intCast(i);
        if (tree.tokenTag(token) != .builtin or !std.mem.eql(u8, tree.tokenSlice(token), "@import")) continue;
        const imported = importValue(tree, i) orelse return false;
        if (sliceContains(named_imports, imported)) continue;
        if (std.mem.indexOfAny(u8, imported, "/\\") != null or std.mem.indexOf(u8, imported, "..") != null or
            !std.mem.startsWith(u8, imported, relative_prefix) or !std.mem.endsWith(u8, imported, ".zig")) return false;
    }
    return true;
}

fn relativeImportResolves(
    source_path: []const u8,
    imported: []const u8,
    scope_files: []const []const u8,
) bool {
    if (!std.mem.endsWith(u8, imported, ".zig") or imported.len == 0 or
        imported[0] == '/' or imported[0] == '\\' or std.mem.indexOfScalar(u8, imported, '\\') != null or
        (imported.len >= 2 and std.ascii.isAlphabetic(imported[0]) and imported[1] == ':')) return false;
    var components = std.mem.splitScalar(u8, imported, '/');
    while (components.next()) |component| {
        if (component.len == 0 or std.mem.eql(u8, component, ".") or std.mem.eql(u8, component, "..")) return false;
    }
    var buffer: [std.fs.max_path_bytes]u8 = undefined;
    const directory = std.fs.path.dirname(source_path) orelse return false;
    const resolved = std.fmt.bufPrint(&buffer, "{s}/{s}", .{ directory, imported }) catch return false;
    return sliceContains(scope_files, resolved);
}

fn importValue(tree: *const std.zig.Ast, index: usize) ?[]const u8 {
    if (!tokenSequence(tree, index, &.{ .builtin, .l_paren, .string_literal, .r_paren })) return null;
    return stringLiteralValue(tree.tokenSlice(@intCast(index + 2)));
}

fn tokenSequence(
    tree: *const std.zig.Ast,
    start_token: anytype,
    expected: []const std.zig.Token.Tag,
) bool {
    const start: usize = @intCast(start_token);
    if (start + expected.len > tree.tokens.len) return false;
    for (expected, 0..) |tag, offset| {
        if (tree.tokenTag(@intCast(start + offset)) != tag) return false;
    }
    return true;
}

fn stringLiteralValue(literal: []const u8) ?[]const u8 {
    if (literal.len < 2 or literal[0] != '"' or literal[literal.len - 1] != '"' or
        std.mem.indexOfScalar(u8, literal[1 .. literal.len - 1], '\\') != null) return null;
    return literal[1 .. literal.len - 1];
}

fn sliceContains(haystack: []const []const u8, needle: []const u8) bool {
    for (haystack) |item| if (std.mem.eql(u8, item, needle)) return true;
    return false;
}

fn indexOf(haystack: []const []const u8, needle: []const u8) ?usize {
    for (haystack, 0..) |item, index| if (std.mem.eql(u8, item, needle)) return index;
    return null;
}

const ParsedSource = struct {
    tree: std.zig.Ast,
    sentinel_source: [:0]u8,

    fn init(allocator: std.mem.Allocator, source: []const u8) ?ParsedSource {
        const sentinel_source = allocator.dupeZ(u8, source) catch return null;
        var tree = std.zig.Ast.parse(allocator, sentinel_source, .zig) catch {
            allocator.free(sentinel_source);
            return null;
        };
        if (tree.errors.len != 0) {
            tree.deinit(allocator);
            allocator.free(sentinel_source);
            return null;
        }
        return .{ .tree = tree, .sentinel_source = sentinel_source };
    }

    fn deinit(self: *ParsedSource, allocator: std.mem.Allocator) void {
        self.tree.deinit(allocator);
        allocator.free(self.sentinel_source);
    }
};

const PublicServiceModules = struct {
    shared: *std.Build.Module,
    persistence: *std.Build.Module,
    migrations: *std.Build.Module,
};

fn createPublicServiceModules(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    abi_library: *std.Build.Step.Compile,
) PublicServiceModules {
    const adapter = createAdapterModule(b, target, optimize, abi_library);
    const shared_probe = createCoverageProbeModule(
        b,
        target,
        "src/platform/persistence/shovelerdb_shared_coverage_probe.zig",
    );
    const shared = createSharedModule(b, target, optimize, shared_probe, false);
    const persistence_probe = createCoverageProbeModule(
        b,
        target,
        "src/platform/persistence/shovelerdb_persistence_coverage_probe.zig",
    );
    const persistence = createPersistenceModule(
        b,
        target,
        optimize,
        adapter,
        shared,
        persistence_probe,
        false,
    );
    const migration_probe = createCoverageProbeModule(
        b,
        target,
        "src/platform/persistence/shovelerdb_coverage_probe.zig",
    );
    const migrations = createMigrationModule(
        b,
        "src/platform/persistence/migrations.zig",
        target,
        optimize,
        adapter,
        migration_probe,
        shared,
        persistence,
        false,
    );
    return .{
        .shared = shared,
        .persistence = persistence,
        .migrations = migrations,
    };
}

fn configureHttp(
    b: *std.Build,
    snapshot: Snapshot,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    abi_library: *std.Build.Step.Compile,
    test_step: *std.Build.Step,
    run_step: *std.Build.Step,
) void {
    const producer = pathExists(b, "src/main.zig") or pathExists(b, "src/http") or snapshot.count(.http) > 0;
    if (!producer) {
        missingProducer(b, test_step, "[test-http:error] expected src/main.zig, src/http/**, and tests/http/** from owning WP08; observed producer absent, count 0");
        missingProducer(b, run_step, "[run:error] expected src/main.zig and src/http/** from owning WP08; observed producer absent, count 0");
        return;
    }
    const public_graph_complete = pathExists(b, "src/shared/root.zig") and
        pathExists(b, "src/platform/persistence/root.zig") and
        pathExists(b, "src/platform/persistence/migrations.zig");
    if (!pathExists(b, "src/main.zig") or !pathExists(b, "src/http/root.zig") or
        snapshot.count(.http) == 0 or !public_graph_complete)
    {
        missingProducer(b, test_step, "[test-http:error] WP08 producer present but HTTP roots or named shared/persistence/migrations module graph are missing");
        missingProducer(b, run_step, "[run:error] WP08 producer present but src/main.zig, src/http/root.zig, or named shared/persistence/migrations module graph is missing");
        return;
    }

    const materialize = b.addSystemCommand(&.{ "npm", "run", "contracts:generate" });
    materialize.setCwd(b.path("../.."));
    const modules = createPublicServiceModules(b, target, optimize, abi_library);
    const http_imports = [_]std.Build.Module.Import{
        .{ .name = "shared", .module = modules.shared },
        .{ .name = "persistence", .module = modules.persistence },
        .{ .name = "migrations", .module = modules.migrations },
    };
    const http = b.createModule(.{
        .root_source_file = b.path("src/http/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &http_imports,
    });
    const composition_imports = [_]std.Build.Module.Import{
        .{ .name = "shared", .module = modules.shared },
        .{ .name = "persistence", .module = modules.persistence },
        .{ .name = "migrations", .module = modules.migrations },
        .{ .name = "http", .module = http },
    };
    const composition = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &composition_imports,
    });
    const executable = b.addExecutable(.{
        .name = "invoice-manager-api",
        .root_module = composition,
    });
    executable.step.dependOn(&materialize.step);

    const test_config = b.addOptions();
    test_config.addOptionPath("api_executable_path", executable.getEmittedBin());
    const test_imports = [_]std.Build.Module.Import{
        .{ .name = "shared", .module = modules.shared },
        .{ .name = "persistence", .module = modules.persistence },
        .{ .name = "migrations", .module = modules.migrations },
        .{ .name = "http", .module = http },
        .{ .name = "composition", .module = composition },
        .{ .name = "http_test_config", .module = test_config.createModule() },
    };
    addGroupTestsAfter(
        b,
        snapshot,
        .http,
        target,
        optimize,
        &test_imports,
        &materialize.step,
        test_step,
    );

    const run = b.addRunArtifact(executable);
    if (b.args) |args| run.addArgs(args);
    run_step.dependOn(&run.step);
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
