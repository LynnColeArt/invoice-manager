const std = @import("std");
const builtin = @import("builtin");
const migration_coverage = @import("migration_coverage_probe");
const shared = @import("shared");
const persistence = @import("persistence");

pub const MigrationError = error{
    OutOfMemory,
    DiscoveryFailure,
    MissingManifest,
    MissingScript,
    MalformedManifest,
    UnknownDescriptorField,
    InvalidUuid,
    OwnerMismatch,
    DirectoryMismatch,
    PathTraversal,
    SymlinkEscape,
    NoncanonicalDependencies,
    ScriptDigestMismatch,
    DescriptorDigestMismatch,
    DuplicateMigrationId,
    DuplicateDescriptorPath,
    MissingDependency,
    SelfDependency,
    DependencyCycle,
    GraphCapacityExceeded,
    CorruptAppliedHistory,
    DuplicateAppliedHistory,
    AppliedIdDrift,
    AppliedOwnerDrift,
    AppliedDescriptorDrift,
    AppliedScriptDrift,
    DdlFailure,
    CheckpointFailure,
    DirectorySyncFailure,
    ReopenFailure,
    RecoveryQuarantine,
    DurabilityUnconfirmed,
    UnsupportedDirectorySync,
    CommittedNotDurable,
    CheckpointedNotDurable,
    LaterMigrationBlocked,
    AllocationFailureCleanup,
};

pub const CriticalCategory = enum {
    discovery_failure,
    missing_manifest,
    missing_script,
    malformed_manifest,
    unknown_descriptor_field,
    invalid_uuid,
    owner_mismatch,
    directory_mismatch,
    path_traversal,
    symlink_escape,
    noncanonical_dependencies,
    script_digest_mismatch,
    descriptor_digest_mismatch,
    duplicate_migration_id,
    duplicate_descriptor_path,
    missing_dependency,
    self_dependency,
    dependency_cycle,
    graph_capacity_exceeded,
    corrupt_applied_history,
    duplicate_applied_history,
    applied_id_drift,
    applied_owner_drift,
    applied_descriptor_drift,
    applied_script_drift,
    ddl_failure,
    checkpoint_failure,
    directory_sync_failure,
    reopen_failure,
    recovery_quarantine,
    durability_unconfirmed,
    unsupported_directory_sync,
    committed_not_durable,
    checkpointed_not_durable,
    later_migration_blocked,
    allocation_failure_cleanup,
};

pub const OwnerRoot = struct {
    owner: []const u8,
    path: []const u8,
};

pub const Descriptor = struct {
    id: []u8,
    owner: []u8,
    name: []u8,
    depends_on: [][]u8,
    script_path: []u8,
    script_digest: []u8,
    descriptor_digest: []u8,
    script: []u8,
    source_path: []u8,

    fn deinit(self: *Descriptor, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.owner);
        allocator.free(self.name);
        for (self.depends_on) |dependency| allocator.free(dependency);
        allocator.free(self.depends_on);
        allocator.free(self.script_path);
        allocator.free(self.script_digest);
        allocator.free(self.descriptor_digest);
        allocator.free(self.script);
        allocator.free(self.source_path);
    }
};

pub const Discovery = struct {
    allocator: std.mem.Allocator,
    descriptors: []Descriptor,

    pub fn deinit(self: *Discovery) void {
        for (self.descriptors) |*descriptor| descriptor.deinit(self.allocator);
        self.allocator.free(self.descriptors);
        self.* = undefined;
    }
};

pub const PlanDiagnostic = struct {
    category: ?CriticalCategory = null,
    ids: [16][36]u8 = undefined,
    ids_len: usize = 0,

    pub fn id(self: *const PlanDiagnostic, index: usize) ?[]const u8 {
        if (index >= self.ids_len) return null;
        return &self.ids[index];
    }
};

pub const Plan = struct {
    allocator: std.mem.Allocator,
    order: []usize,

    pub fn deinit(self: *Plan) void {
        self.allocator.free(self.order);
        self.* = undefined;
    }
};

pub const ReadinessStatus = enum {
    ready,
    durability_unconfirmed,
    recovery_quarantine,
};

pub const Readiness = struct {
    status: ReadinessStatus,
    category: ?CriticalCategory = null,
    discovered_count: usize,
    applied_count: usize,
    already_applied_count: usize,
    application_complete: bool,
    checkpoint_complete: bool,
    directory_sync_complete: bool,
    durable_reopen_complete: bool,

    pub fn isReady(self: Readiness) bool {
        return self.status == .ready and self.application_complete and
            self.checkpoint_complete and self.directory_sync_complete and
            self.durable_reopen_complete;
    }
};

const ManifestWire = struct {
    id: []const u8,
    owner: []const u8,
    name: []const u8,
    depends_on: []const []const u8,
    script_path: []const u8,
    script_digest: []const u8,
    descriptor_digest: []const u8,
};

const maximum_graph_size = 1024;
const maximum_file_bytes = 1024 * 1024;
const bootstrap_id = "018f6f10-7b7a-7c2d-8e65-0f7b1c2d3e4f";
const bootstrap_script_digest = "sha256:68dff6daa265a0c0c6d603994438c43a0af3228fff72e677d9dcd0cd60b1fbd3";
const bootstrap_descriptor_digest = "sha256:0b5af56a66a73c1f0f96b76ad4307a6e3a76f3cd34cb0ba71197a5e90d4e7877";

pub fn discover(
    allocator: std.mem.Allocator,
    io: std.Io,
    roots: []const OwnerRoot,
) MigrationError!Discovery {
    var descriptors: std.ArrayList(Descriptor) = .empty;
    errdefer {
        for (descriptors.items) |*descriptor| descriptor.deinit(allocator);
        descriptors.deinit(allocator);
    }
    for (roots) |root| try discoverRoot(allocator, io, root, &descriptors);
    std.mem.sort(Descriptor, descriptors.items, {}, struct {
        fn lessThan(_: void, left: Descriptor, right: Descriptor) bool {
            return std.mem.lessThan(u8, left.id, right.id);
        }
    }.lessThan);
    return .{ .allocator = allocator, .descriptors = descriptors.toOwnedSlice(allocator) catch return allocationFailure() };
}

fn discoverRoot(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: OwnerRoot,
    descriptors: *std.ArrayList(Descriptor),
) MigrationError!void {
    if (!validOwner(root.owner)) return criticalError(.owner_mismatch);
    if (std.fs.path.isAbsolute(root.path) or containsTraversal(root.path)) {
        return criticalError(.path_traversal);
    }
    var directory = std.Io.Dir.openDir(.cwd(), io, root.path, .{
        .iterate = true,
        .follow_symlinks = false,
    }) catch return criticalError(.discovery_failure);
    defer directory.close(io);
    var walker = directory.walk(allocator) catch return allocationFailure();
    defer walker.deinit();
    var candidate_ids: std.ArrayList([]u8) = .empty;
    defer {
        for (candidate_ids.items) |candidate| allocator.free(candidate);
        candidate_ids.deinit(allocator);
    }
    while (walker.next(io) catch return criticalError(.discovery_failure)) |entry| {
        if (entry.kind == .sym_link) return criticalError(.symlink_escape);
        if (entry.kind == .directory and entry.depth() == 1 and looksLikeUuid(entry.path)) {
            const candidate = allocator.dupe(u8, entry.path) catch return allocationFailure();
            candidate_ids.append(allocator, candidate) catch {
                allocator.free(candidate);
                return allocationFailure();
            };
            continue;
        }
        if (entry.kind != .file or !std.mem.eql(u8, entry.basename, "manifest.json")) continue;
        if (entry.depth() != 2) return criticalError(.directory_mismatch);
        const directory_name = std.fs.path.dirname(entry.path) orelse return criticalError(.directory_mismatch);
        if (std.mem.indexOfScalar(u8, directory_name, std.fs.path.sep) != null) {
            return criticalError(.directory_mismatch);
        }
        var descriptor = try parseDescriptor(allocator, io, directory, root, directory_name, entry.path);
        errdefer descriptor.deinit(allocator);
        for (descriptors.items) |existing| {
            if (std.mem.eql(u8, existing.source_path, descriptor.source_path)) {
                return criticalError(.duplicate_descriptor_path);
            }
        }
        descriptors.append(allocator, descriptor) catch return allocationFailure();
    }
    for (candidate_ids.items) |candidate| {
        var found = false;
        for (descriptors.items) |descriptor| {
            if (std.mem.eql(u8, descriptor.id, candidate) and std.mem.eql(u8, descriptor.owner, root.owner)) {
                found = true;
                break;
            }
        }
        if (!found) return criticalError(.missing_manifest);
    }
}

fn parseDescriptor(
    allocator: std.mem.Allocator,
    io: std.Io,
    directory: std.Io.Dir,
    root: OwnerRoot,
    directory_name: []const u8,
    manifest_path: []const u8,
) MigrationError!Descriptor {
    const manifest_bytes = directory.readFileAlloc(io, manifest_path, allocator, .limited(maximum_file_bytes)) catch
        return criticalError(.missing_manifest);
    defer allocator.free(manifest_bytes);
    var dynamic = std.json.parseFromSlice(std.json.Value, allocator, manifest_bytes, .{}) catch
        return criticalError(.malformed_manifest);
    defer dynamic.deinit();
    const object = switch (dynamic.value) {
        .object => |object| object,
        else => return criticalError(.malformed_manifest),
    };
    var object_iterator = object.iterator();
    while (object_iterator.next()) |entry| {
        if (!knownManifestField(entry.key_ptr.*)) return criticalError(.unknown_descriptor_field);
    }
    var parsed = std.json.parseFromSlice(ManifestWire, allocator, manifest_bytes, .{ .allocate = .alloc_always }) catch
        return criticalError(.malformed_manifest);
    defer parsed.deinit();
    const wire = parsed.value;
    _ = shared.EntityId.parse(wire.id) catch return criticalError(.invalid_uuid);
    if (!std.mem.eql(u8, wire.id, directory_name)) return criticalError(.directory_mismatch);
    if (!std.mem.eql(u8, wire.owner, root.owner)) return criticalError(.owner_mismatch);
    if (!validName(wire.name)) return criticalError(.malformed_manifest);
    if (!std.mem.eql(u8, wire.script_path, "up.sql")) return criticalError(.path_traversal);
    if (!dependenciesCanonical(wire.depends_on)) return criticalError(.noncanonical_dependencies);
    _ = shared.Sha256Digest.parse(wire.script_digest) catch return criticalError(.script_digest_mismatch);
    _ = shared.Sha256Digest.parse(wire.descriptor_digest) catch return criticalError(.descriptor_digest_mismatch);

    const script_relative = std.fmt.allocPrint(allocator, "{s}/up.sql", .{directory_name}) catch return allocationFailure();
    defer allocator.free(script_relative);
    const script_stat = directory.statFile(io, script_relative, .{ .follow_symlinks = false }) catch
        return criticalError(.missing_script);
    if (script_stat.kind == .sym_link) return criticalError(.symlink_escape);
    if (script_stat.kind != .file) return criticalError(.missing_script);
    const script = directory.readFileAlloc(io, script_relative, allocator, .limited(maximum_file_bytes)) catch
        return criticalError(.missing_script);
    errdefer allocator.free(script);
    var script_digest_buffer: [71]u8 = undefined;
    const computed_script_digest = sha256Wire(script, &script_digest_buffer);
    if (!std.mem.eql(u8, computed_script_digest, wire.script_digest)) {
        return criticalError(.script_digest_mismatch);
    }
    const canonical = canonicalProjectionAlloc(allocator, wire) catch return allocationFailure();
    defer allocator.free(canonical);
    var descriptor_digest_buffer: [71]u8 = undefined;
    const computed_descriptor_digest = sha256Wire(canonical, &descriptor_digest_buffer);
    if (!std.mem.eql(u8, computed_descriptor_digest, wire.descriptor_digest)) {
        return criticalError(.descriptor_digest_mismatch);
    }

    const dependencies = allocator.alloc([]u8, wire.depends_on.len) catch return allocationFailure();
    var dependency_count: usize = 0;
    errdefer {
        for (dependencies[0..dependency_count]) |dependency| allocator.free(dependency);
        allocator.free(dependencies);
    }
    for (wire.depends_on) |dependency| {
        _ = shared.EntityId.parse(dependency) catch return criticalError(.invalid_uuid);
        dependencies[dependency_count] = allocator.dupe(u8, dependency) catch return allocationFailure();
        dependency_count += 1;
    }
    const source_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ root.path, manifest_path }) catch return allocationFailure();
    errdefer allocator.free(source_path);
    const id = allocator.dupe(u8, wire.id) catch return allocationFailure();
    errdefer allocator.free(id);
    const owner = allocator.dupe(u8, wire.owner) catch return allocationFailure();
    errdefer allocator.free(owner);
    const name = allocator.dupe(u8, wire.name) catch return allocationFailure();
    errdefer allocator.free(name);
    const script_path = allocator.dupe(u8, wire.script_path) catch return allocationFailure();
    errdefer allocator.free(script_path);
    const script_digest = allocator.dupe(u8, wire.script_digest) catch return allocationFailure();
    errdefer allocator.free(script_digest);
    const descriptor_digest = allocator.dupe(u8, wire.descriptor_digest) catch return allocationFailure();
    errdefer allocator.free(descriptor_digest);
    return .{
        .id = id,
        .owner = owner,
        .name = name,
        .depends_on = dependencies,
        .script_path = script_path,
        .script_digest = script_digest,
        .descriptor_digest = descriptor_digest,
        .script = script,
        .source_path = source_path,
    };
}

pub fn canonicalProjection(
    allocator: std.mem.Allocator,
    id: []const u8,
    owner: []const u8,
    name: []const u8,
    dependencies: []const []const u8,
    script_path: []const u8,
    script_digest: []const u8,
) MigrationError![]u8 {
    const sorted = allocator.alloc([]const u8, dependencies.len) catch return allocationFailure();
    defer allocator.free(sorted);
    @memcpy(sorted, dependencies);
    std.mem.sort([]const u8, sorted, {}, struct {
        fn lessThan(_: void, left: []const u8, right: []const u8) bool {
            return std.mem.lessThan(u8, left, right);
        }
    }.lessThan);
    return canonicalProjectionParts(allocator, id, owner, name, sorted, script_path, script_digest) catch return allocationFailure();
}

fn canonicalProjectionAlloc(allocator: std.mem.Allocator, wire: ManifestWire) ![]u8 {
    return canonicalProjectionParts(
        allocator,
        wire.id,
        wire.owner,
        wire.name,
        wire.depends_on,
        wire.script_path,
        wire.script_digest,
    );
}

fn canonicalProjectionParts(
    allocator: std.mem.Allocator,
    id: []const u8,
    owner: []const u8,
    name: []const u8,
    dependencies: []const []const u8,
    script_path: []const u8,
    script_digest: []const u8,
) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendSlice(allocator, "{\"depends_on\":[");
    for (dependencies, 0..) |dependency, index| {
        if (index != 0) try output.append(allocator, ',');
        try appendJsonString(allocator, &output, dependency);
    }
    try output.appendSlice(allocator, "],\"id\":");
    try appendJsonString(allocator, &output, id);
    try output.appendSlice(allocator, ",\"name\":");
    try appendJsonString(allocator, &output, name);
    try output.appendSlice(allocator, ",\"owner\":");
    try appendJsonString(allocator, &output, owner);
    try output.appendSlice(allocator, ",\"script_digest\":");
    try appendJsonString(allocator, &output, script_digest);
    try output.appendSlice(allocator, ",\"script_path\":");
    try appendJsonString(allocator, &output, script_path);
    try output.append(allocator, '}');
    return output.toOwnedSlice(allocator);
}

fn appendJsonString(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) !void {
    try output.append(allocator, '"');
    for (value) |byte| switch (byte) {
        '"' => try output.appendSlice(allocator, "\\\""),
        '\\' => try output.appendSlice(allocator, "\\\\"),
        0...0x1f => return error.InvalidCharacter,
        else => try output.append(allocator, byte),
    };
    try output.append(allocator, '"');
}

pub fn plan(allocator: std.mem.Allocator, descriptors: []const Descriptor) MigrationError!Plan {
    var diagnostic = PlanDiagnostic{};
    return planWithDiagnostic(allocator, descriptors, &diagnostic);
}

pub fn planWithDiagnostic(
    allocator: std.mem.Allocator,
    descriptors: []const Descriptor,
    diagnostic: *PlanDiagnostic,
) MigrationError!Plan {
    diagnostic.* = .{};
    if (descriptors.len > maximum_graph_size) {
        diagnostic.category = .graph_capacity_exceeded;
        return criticalError(.graph_capacity_exceeded);
    }
    for (descriptors, 0..) |left, left_index| {
        for (descriptors[left_index + 1 ..]) |right| {
            if (std.mem.eql(u8, left.source_path, right.source_path)) {
                diagnostic.category = .duplicate_descriptor_path;
                return criticalError(.duplicate_descriptor_path);
            }
            if (std.mem.eql(u8, left.id, right.id)) {
                diagnostic.category = .duplicate_migration_id;
                return criticalError(.duplicate_migration_id);
            }
        }
    }
    const indegree = allocator.alloc(usize, descriptors.len) catch return allocationFailure();
    defer allocator.free(indegree);
    @memset(indegree, 0);
    for (descriptors, 0..) |descriptor, descriptor_index| {
        for (descriptor.depends_on) |dependency| {
            if (std.mem.eql(u8, descriptor.id, dependency)) {
                diagnostic.category = .self_dependency;
                appendDiagnosticId(diagnostic, descriptor.id);
                return criticalError(.self_dependency);
            }
            if (findDescriptor(descriptors, dependency) == null) {
                diagnostic.category = .missing_dependency;
                appendDiagnosticId(diagnostic, dependency);
                return criticalError(.missing_dependency);
            }
            indegree[descriptor_index] += 1;
        }
    }
    const selected = allocator.alloc(bool, descriptors.len) catch return allocationFailure();
    defer allocator.free(selected);
    @memset(selected, false);
    const order = allocator.alloc(usize, descriptors.len) catch return allocationFailure();
    errdefer allocator.free(order);
    var emitted: usize = 0;
    while (emitted < descriptors.len) {
        var candidate: ?usize = null;
        for (descriptors, 0..) |descriptor, index| {
            if (selected[index] or indegree[index] != 0) continue;
            if (candidate == null or std.mem.lessThan(u8, descriptor.id, descriptors[candidate.?].id)) candidate = index;
        }
        const next = candidate orelse {
            diagnostic.category = .dependency_cycle;
            var remaining: std.ArrayList([]const u8) = .empty;
            defer remaining.deinit(allocator);
            for (descriptors, 0..) |descriptor, index| {
                if (!selected[index]) remaining.append(allocator, descriptor.id) catch return allocationFailure();
            }
            std.mem.sort([]const u8, remaining.items, {}, struct {
                fn lessThan(_: void, left: []const u8, right: []const u8) bool {
                    return std.mem.lessThan(u8, left, right);
                }
            }.lessThan);
            for (remaining.items) |id| appendDiagnosticId(diagnostic, id);
            return criticalError(.dependency_cycle);
        };
        selected[next] = true;
        order[emitted] = next;
        emitted += 1;
        for (descriptors, 0..) |descriptor, index| {
            if (selected[index]) continue;
            for (descriptor.depends_on) |dependency| {
                if (std.mem.eql(u8, dependency, descriptors[next].id)) indegree[index] -= 1;
            }
        }
    }
    return .{ .allocator = allocator, .order = order };
}

fn findDescriptor(descriptors: []const Descriptor, id: []const u8) ?usize {
    for (descriptors, 0..) |descriptor, index| {
        if (std.mem.eql(u8, descriptor.id, id)) return index;
    }
    return null;
}

fn appendDiagnosticId(diagnostic: *PlanDiagnostic, id: []const u8) void {
    if (diagnostic.ids_len >= diagnostic.ids.len or id.len != 36) return;
    @memcpy(&diagnostic.ids[diagnostic.ids_len], id);
    diagnostic.ids_len += 1;
}

const AppliedMigration = struct {
    id: []u8,
    owner: []u8,
    descriptor_digest: []u8,
    script_digest: []u8,
    applied_at: []u8,

    fn deinit(self: *AppliedMigration, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.owner);
        allocator.free(self.descriptor_digest);
        allocator.free(self.script_digest);
        allocator.free(self.applied_at);
    }
};

const HistoryContext = struct {
    allocator: std.mem.Allocator,
    rows: std.ArrayList(AppliedMigration) = .empty,
    callback_error: ?anyerror = null,

    fn deinit(self: *HistoryContext) void {
        for (self.rows.items) |*row| row.deinit(self.allocator);
        self.rows.deinit(self.allocator);
    }
};

fn visitApplied(raw_context: *anyopaque, row: *const persistence.RowView) !void {
    const context: *HistoryContext = @ptrCast(@alignCast(raw_context));
    if (row.len() != 5) return error.CorruptAppliedHistory;
    const id = try rowText(row, 0);
    const owner = try rowText(row, 1);
    const descriptor_digest = try rowText(row, 2);
    const script_digest = try rowText(row, 3);
    const applied_at = try rowText(row, 4);
    const owned_id = try context.allocator.dupe(u8, id);
    errdefer context.allocator.free(owned_id);
    const owned_owner = try context.allocator.dupe(u8, owner);
    errdefer context.allocator.free(owned_owner);
    const owned_descriptor_digest = try context.allocator.dupe(u8, descriptor_digest);
    errdefer context.allocator.free(owned_descriptor_digest);
    const owned_script_digest = try context.allocator.dupe(u8, script_digest);
    errdefer context.allocator.free(owned_script_digest);
    const owned_applied_at = try context.allocator.dupe(u8, applied_at);
    errdefer context.allocator.free(owned_applied_at);
    try context.rows.append(context.allocator, .{
        .id = owned_id,
        .owner = owned_owner,
        .descriptor_digest = owned_descriptor_digest,
        .script_digest = owned_script_digest,
        .applied_at = owned_applied_at,
    });
}

fn rowText(row: *const persistence.RowView, index: usize) ![]const u8 {
    return switch (try row.value(index)) {
        .text => |text| text,
        else => error.CorruptAppliedHistory,
    };
}

fn readHistoryCallback(raw_context: *anyopaque, executor: persistence.StartupExecutor) !void {
    const context: *HistoryContext = @ptrCast(@alignCast(raw_context));
    _ = executor.query(
        "SELECT id, owner, descriptor_digest, script_digest, applied_at FROM app_schema_migrations;",
        .{ .context = context, .visit = visitApplied },
    ) catch |err| {
        context.callback_error = err;
        return err;
    };
}

const ApplyContext = struct {
    descriptor: *const Descriptor,
    applied_at: []const u8,
    callback_error: ?anyerror = null,
    application_calls: *usize,
};

fn applyCallback(raw_context: *anyopaque, executor: persistence.StartupExecutor) !void {
    const context: *ApplyContext = @ptrCast(@alignCast(raw_context));
    context.application_calls.* += 1;
    _ = executor.executeScript(context.descriptor.script) catch |err| {
        context.callback_error = err;
        return err;
    };
    _ = executor.executeBound(
        &.{
            "INSERT INTO app_schema_migrations VALUES (",
            ", ",
            ", ",
            ", ",
            ", ",
            ");",
        },
        &.{
            context.descriptor.id,
            context.descriptor.owner,
            context.descriptor.descriptor_digest,
            context.descriptor.script_digest,
            context.applied_at,
        },
    ) catch |err| {
        context.callback_error = err;
        return err;
    };
}

pub fn run(
    allocator: std.mem.Allocator,
    io: std.Io,
    store: *persistence.Store,
    roots: []const OwnerRoot,
    applied_at: []const u8,
) MigrationError!Readiness {
    var ignored_calls: usize = 0;
    return migrationRunObserved(allocator, io, store, roots, applied_at, &ignored_calls);
}

fn migrationRunObserved(
    allocator: std.mem.Allocator,
    io: std.Io,
    store: *persistence.Store,
    roots: []const OwnerRoot,
    applied_at: []const u8,
    application_calls: *usize,
) MigrationError!Readiness {
    _ = shared.UtcInstant.parse(applied_at) catch return criticalError(.corrupt_applied_history);
    var discovered = try discover(allocator, io, roots);
    defer discovered.deinit();
    var ordered = try plan(allocator, discovered.descriptors);
    defer ordered.deinit();

    var history = HistoryContext{ .allocator = allocator };
    defer history.deinit();
    const history_receipt = store.startupWrite(.{
        .context = &history,
        .run = readHistoryCallback,
    }) catch |err| {
        if (err != error.StartupWriteFailed) {
            return mapStoreFailure(store, err, discovered.descriptors.len, 0, 0);
        }
        if (history.callback_error != null and history.callback_error.? == error.StatementObjectFailed and hasExactBootstrap(discovered.descriptors)) {
            history.callback_error = null;
        } else {
            return mapStoreFailure(store, err, discovered.descriptors.len, 0, 0);
        }
        return applyPending(
            store,
            discovered.descriptors,
            ordered.order,
            history.rows.items,
            applied_at,
            application_calls,
        );
    };
    if (history_receipt.durability != .directory_synchronized or store.state() != .ready) {
        return criticalError(.durability_unconfirmed);
    }
    try validateAppliedHistory(discovered.descriptors, history.rows.items);
    return applyPending(
        store,
        discovered.descriptors,
        ordered.order,
        history.rows.items,
        applied_at,
        application_calls,
    );
}

fn applyPending(
    store: *persistence.Store,
    descriptors: []const Descriptor,
    order: []const usize,
    applied: []const AppliedMigration,
    applied_at: []const u8,
    application_calls: *usize,
) MigrationError!Readiness {
    var already_applied: usize = 0;
    var applied_count: usize = 0;
    for (order, 0..) |descriptor_index, order_index| {
        const descriptor = &descriptors[descriptor_index];
        if (findApplied(applied, descriptor.id)) |row| {
            try compareApplied(descriptor, row);
            already_applied += 1;
            continue;
        }
        var context = ApplyContext{
            .descriptor = descriptor,
            .applied_at = applied_at,
            .application_calls = application_calls,
        };
        const receipt = store.startupWrite(.{ .context = &context, .run = applyCallback }) catch |err| {
            if (order_index + 1 < order.len) hitCritical(.later_migration_blocked);
            if (context.callback_error != null) {
                if (store.state() == .quarantined) {
                    hitCritical(.recovery_quarantine);
                    return criticalError(.reopen_failure);
                }
                return criticalError(.ddl_failure);
            }
            return mapStoreFailure(store, err, descriptors.len, applied_count, already_applied);
        };
        if (receipt.durability != .directory_synchronized or store.state() != .ready) {
            return criticalError(.durability_unconfirmed);
        }
        applied_count += 1;
    }
    return .{
        .status = .ready,
        .discovered_count = descriptors.len,
        .applied_count = applied_count,
        .already_applied_count = already_applied,
        .application_complete = true,
        .checkpoint_complete = true,
        .directory_sync_complete = true,
        .durable_reopen_complete = true,
    };
}

fn validateAppliedHistory(descriptors: []const Descriptor, applied: []const AppliedMigration) MigrationError!void {
    for (applied, 0..) |row, index| {
        _ = shared.EntityId.parse(row.id) catch return criticalError(.corrupt_applied_history);
        _ = shared.Sha256Digest.parse(row.descriptor_digest) catch return criticalError(.corrupt_applied_history);
        _ = shared.Sha256Digest.parse(row.script_digest) catch return criticalError(.corrupt_applied_history);
        _ = shared.UtcInstant.parse(row.applied_at) catch return criticalError(.corrupt_applied_history);
        for (applied[index + 1 ..]) |other| {
            if (std.mem.eql(u8, row.id, other.id)) return criticalError(.duplicate_applied_history);
        }
        const descriptor_index = findDescriptor(descriptors, row.id) orelse return criticalError(.applied_id_drift);
        try compareApplied(&descriptors[descriptor_index], row);
    }
}

fn compareApplied(descriptor: *const Descriptor, row: AppliedMigration) MigrationError!void {
    if (!std.mem.eql(u8, descriptor.owner, row.owner)) return criticalError(.applied_owner_drift);
    if (!std.mem.eql(u8, descriptor.descriptor_digest, row.descriptor_digest)) return criticalError(.applied_descriptor_drift);
    if (!std.mem.eql(u8, descriptor.script_digest, row.script_digest)) return criticalError(.applied_script_drift);
}

fn findApplied(applied: []const AppliedMigration, id: []const u8) ?AppliedMigration {
    for (applied) |row| if (std.mem.eql(u8, row.id, id)) return row;
    return null;
}

fn hasExactBootstrap(descriptors: []const Descriptor) bool {
    for (descriptors) |descriptor| {
        if (std.mem.eql(u8, descriptor.id, bootstrap_id) and
            std.mem.eql(u8, descriptor.owner, "p0") and
            std.mem.eql(u8, descriptor.script_digest, bootstrap_script_digest) and
            std.mem.eql(u8, descriptor.descriptor_digest, bootstrap_descriptor_digest)) return true;
    }
    return false;
}

fn mapStoreFailure(
    store: *persistence.Store,
    store_error: anyerror,
    discovered_count: usize,
    applied_count: usize,
    already_applied_count: usize,
) MigrationError!Readiness {
    return switch (store_error) {
        error.CheckpointFailed => durabilityFailure(.checkpoint_failure, .committed_not_durable, discovered_count, applied_count, already_applied_count),
        error.DirectoryOpenFailed, error.DirectorySyncFailed, error.DirectoryCloseFailed => durabilityFailure(.directory_sync_failure, .checkpointed_not_durable, discovered_count, applied_count, already_applied_count),
        error.UnsupportedDirectorySync => durabilityFailure(.unsupported_directory_sync, .checkpointed_not_durable, discovered_count, applied_count, already_applied_count),
        error.ReopenFailed => {
            _ = store;
            hitCritical(.recovery_quarantine);
            return criticalError(.reopen_failure);
        },
        error.DirtyDiscardFailed => criticalError(.recovery_quarantine),
        else => criticalError(.corrupt_applied_history),
    };
}

fn durabilityFailure(
    comptime category: CriticalCategory,
    comptime boundary: CriticalCategory,
    discovered_count: usize,
    applied_count: usize,
    already_applied_count: usize,
) Readiness {
    hitCritical(category);
    hitCritical(boundary);
    hitCritical(.durability_unconfirmed);
    return .{
        .status = .durability_unconfirmed,
        .category = category,
        .discovered_count = discovered_count,
        .applied_count = applied_count,
        .already_applied_count = already_applied_count,
        .application_complete = true,
        .checkpoint_complete = boundary == .checkpointed_not_durable,
        .directory_sync_complete = false,
        .durable_reopen_complete = true,
    };
}

pub fn completeDurability(store: *persistence.Store, prior: Readiness) MigrationError!Readiness {
    const receipt = store.completeDurability() catch |err| return mapStoreFailure(
        store,
        err,
        prior.discovered_count,
        prior.applied_count,
        prior.already_applied_count,
    );
    if (receipt.durability != .directory_synchronized or store.state() != .ready) {
        return criticalError(.durability_unconfirmed);
    }
    return .{
        .status = .ready,
        .discovered_count = prior.discovered_count,
        .applied_count = prior.applied_count,
        .already_applied_count = prior.already_applied_count,
        .application_complete = true,
        .checkpoint_complete = true,
        .directory_sync_complete = true,
        .durable_reopen_complete = true,
    };
}

fn knownManifestField(field: []const u8) bool {
    return std.mem.eql(u8, field, "id") or
        std.mem.eql(u8, field, "owner") or
        std.mem.eql(u8, field, "name") or
        std.mem.eql(u8, field, "depends_on") or
        std.mem.eql(u8, field, "script_path") or
        std.mem.eql(u8, field, "script_digest") or
        std.mem.eql(u8, field, "descriptor_digest");
}

fn validOwner(owner: []const u8) bool {
    return owner.len == 2 and owner[0] == 'p' and owner[1] >= '0' and owner[1] <= '8';
}

fn validName(name: []const u8) bool {
    if (name.len == 0 or name[0] < 'a' or name[0] > 'z') return false;
    for (name[1..]) |byte| if (!((byte >= 'a' and byte <= 'z') or (byte >= '0' and byte <= '9') or byte == '_')) return false;
    return true;
}

fn containsTraversal(path: []const u8) bool {
    var iterator = std.mem.splitScalar(u8, path, std.fs.path.sep);
    while (iterator.next()) |component| if (std.mem.eql(u8, component, "..")) return true;
    return false;
}

fn looksLikeUuid(path: []const u8) bool {
    return path.len == 36 and path[8] == '-' and path[13] == '-' and path[18] == '-' and path[23] == '-';
}

fn dependenciesCanonical(dependencies: []const []const u8) bool {
    for (dependencies, 0..) |dependency, index| {
        _ = shared.EntityId.parse(dependency) catch return false;
        if (index != 0 and !std.mem.lessThan(u8, dependencies[index - 1], dependency)) return false;
    }
    return true;
}

fn sha256Wire(bytes: []const u8, output: *[71]u8) []const u8 {
    @memcpy(output[0..7], "sha256:");
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    const hex = std.fmt.bytesToHex(digest, .lower);
    @memcpy(output[7..], &hex);
    return output;
}

fn allocationFailure() MigrationError {
    return criticalError(.allocation_failure_cleanup);
}

fn criticalError(comptime category: CriticalCategory) MigrationError {
    hitCritical(category);
    return expectedError(category);
}

pub fn expectedError(category: CriticalCategory) MigrationError {
    return switch (category) {
        .discovery_failure => error.DiscoveryFailure,
        .missing_manifest => error.MissingManifest,
        .missing_script => error.MissingScript,
        .malformed_manifest => error.MalformedManifest,
        .unknown_descriptor_field => error.UnknownDescriptorField,
        .invalid_uuid => error.InvalidUuid,
        .owner_mismatch => error.OwnerMismatch,
        .directory_mismatch => error.DirectoryMismatch,
        .path_traversal => error.PathTraversal,
        .symlink_escape => error.SymlinkEscape,
        .noncanonical_dependencies => error.NoncanonicalDependencies,
        .script_digest_mismatch => error.ScriptDigestMismatch,
        .descriptor_digest_mismatch => error.DescriptorDigestMismatch,
        .duplicate_migration_id => error.DuplicateMigrationId,
        .duplicate_descriptor_path => error.DuplicateDescriptorPath,
        .missing_dependency => error.MissingDependency,
        .self_dependency => error.SelfDependency,
        .dependency_cycle => error.DependencyCycle,
        .graph_capacity_exceeded => error.GraphCapacityExceeded,
        .corrupt_applied_history => error.CorruptAppliedHistory,
        .duplicate_applied_history => error.DuplicateAppliedHistory,
        .applied_id_drift => error.AppliedIdDrift,
        .applied_owner_drift => error.AppliedOwnerDrift,
        .applied_descriptor_drift => error.AppliedDescriptorDrift,
        .applied_script_drift => error.AppliedScriptDrift,
        .ddl_failure => error.DdlFailure,
        .checkpoint_failure => error.CheckpointFailure,
        .directory_sync_failure => error.DirectorySyncFailure,
        .reopen_failure => error.ReopenFailure,
        .recovery_quarantine => error.RecoveryQuarantine,
        .durability_unconfirmed => error.DurabilityUnconfirmed,
        .unsupported_directory_sync => error.UnsupportedDirectorySync,
        .committed_not_durable => error.CommittedNotDurable,
        .checkpointed_not_durable => error.CheckpointedNotDurable,
        .later_migration_blocked => error.LaterMigrationBlocked,
        .allocation_failure_cleanup => error.AllocationFailureCleanup,
    };
}

fn hitCritical(comptime category: CriticalCategory) void {
    switch (category) {
        .discovery_failure => migration_coverage.hit(.discovery_failure),
        .missing_manifest => migration_coverage.hit(.missing_manifest),
        .missing_script => migration_coverage.hit(.missing_script),
        .malformed_manifest => migration_coverage.hit(.malformed_manifest),
        .unknown_descriptor_field => migration_coverage.hit(.unknown_descriptor_field),
        .invalid_uuid => migration_coverage.hit(.invalid_uuid),
        .owner_mismatch => migration_coverage.hit(.owner_mismatch),
        .directory_mismatch => migration_coverage.hit(.directory_mismatch),
        .path_traversal => migration_coverage.hit(.path_traversal),
        .symlink_escape => migration_coverage.hit(.symlink_escape),
        .noncanonical_dependencies => migration_coverage.hit(.noncanonical_dependencies),
        .script_digest_mismatch => migration_coverage.hit(.script_digest_mismatch),
        .descriptor_digest_mismatch => migration_coverage.hit(.descriptor_digest_mismatch),
        .duplicate_migration_id => migration_coverage.hit(.duplicate_migration_id),
        .duplicate_descriptor_path => migration_coverage.hit(.duplicate_descriptor_path),
        .missing_dependency => migration_coverage.hit(.missing_dependency),
        .self_dependency => migration_coverage.hit(.self_dependency),
        .dependency_cycle => migration_coverage.hit(.dependency_cycle),
        .graph_capacity_exceeded => migration_coverage.hit(.graph_capacity_exceeded),
        .corrupt_applied_history => migration_coverage.hit(.corrupt_applied_history),
        .duplicate_applied_history => migration_coverage.hit(.duplicate_applied_history),
        .applied_id_drift => migration_coverage.hit(.applied_id_drift),
        .applied_owner_drift => migration_coverage.hit(.applied_owner_drift),
        .applied_descriptor_drift => migration_coverage.hit(.applied_descriptor_drift),
        .applied_script_drift => migration_coverage.hit(.applied_script_drift),
        .ddl_failure => migration_coverage.hit(.ddl_failure),
        .checkpoint_failure => migration_coverage.hit(.checkpoint_failure),
        .directory_sync_failure => migration_coverage.hit(.directory_sync_failure),
        .reopen_failure => migration_coverage.hit(.reopen_failure),
        .recovery_quarantine => migration_coverage.hit(.recovery_quarantine),
        .durability_unconfirmed => migration_coverage.hit(.durability_unconfirmed),
        .unsupported_directory_sync => migration_coverage.hit(.unsupported_directory_sync),
        .committed_not_durable => migration_coverage.hit(.committed_not_durable),
        .checkpointed_not_durable => migration_coverage.hit(.checkpointed_not_durable),
        .later_migration_blocked => migration_coverage.hit(.later_migration_blocked),
        .allocation_failure_cleanup => migration_coverage.hit(.allocation_failure_cleanup),
    }
}

pub const testing = if (builtin.is_test) struct {
    pub const Store = persistence.Store;
    pub const StartupExecutor = persistence.StartupExecutor;
    pub const Faults = persistence.testing.Faults;
    pub const openStoreWithFaults = persistence.testing.openWithFaults;
    pub const setFaults = persistence.testing.setFaults;
    pub const checkpointCount = persistence.testing.checkpointCount;
    pub const discardCount = persistence.testing.discardCount;
    pub const reopenCount = persistence.testing.reopenCount;
    pub const rowCount = persistence.testing.rowCount;

    pub fn runObserved(
        allocator: std.mem.Allocator,
        io: std.Io,
        store: *Store,
        roots: []const OwnerRoot,
        applied_at: []const u8,
        application_calls: *usize,
    ) MigrationError!Readiness {
        return migrationRunObserved(allocator, io, store, roots, applied_at, application_calls);
    }
} else struct {};
