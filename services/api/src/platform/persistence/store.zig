const std = @import("std");
const shovelerdb = @import("shovelerdb_adapter");
const persistence_coverage = @import("persistence_coverage_probe");
const diagnostics = @import("diagnostics.zig");
const durability = @import("durability.zig");
const directory_sync = @import("directory_sync.zig");

pub const Store = struct {
    _implementation: ?*anyopaque,
    _terminal_state: diagnostics.State = .closed,
    _terminal_diagnostic: ?diagnostics.Diagnostic = null,

    pub fn open(
        allocator: std.mem.Allocator,
        io: std.Io,
        path: []const u8,
    ) diagnostics.StoreError!Store {
        return openWithFaults(allocator, io, path, .{});
    }

    pub fn state(self: *const Store) diagnostics.State {
        const impl_ptr = self.constImplementation() orelse return self._terminal_state;
        return impl_ptr.lifecycle;
    }

    pub fn lastDiagnostic(self: *const Store) ?diagnostics.Diagnostic {
        const impl_ptr = self.constImplementation() orelse return self._terminal_diagnostic;
        return impl_ptr.diagnostic;
    }

    pub fn mutate(self: *Store, operation: durability.WriteOperation) diagnostics.StoreError!durability.DurableReceipt {
        const impl_ptr = self.implementation() orelse return diagnostics.StoreError.StoreClosed;
        return impl_ptr.mutate(operation);
    }

    pub fn startupWrite(self: *Store, operation: durability.WriteOperation) diagnostics.StoreError!durability.DurableReceipt {
        const impl_ptr = self.implementation() orelse return diagnostics.StoreError.StoreClosed;
        return impl_ptr.startupWrite(operation);
    }

    pub fn shutdown(self: *Store) diagnostics.StoreError!void {
        const impl_ptr = self.implementation() orelse return;
        const allocator = impl_ptr.allocator;
        const result = impl_ptr.shutdown();
        self._terminal_state = impl_ptr.lifecycle;
        self._terminal_diagnostic = impl_ptr.diagnostic;
        allocator.destroy(impl_ptr);
        self._implementation = null;
        return result;
    }

    fn implementation(self: *Store) ?*StoreImpl {
        return @ptrCast(@alignCast(self._implementation orelse return null));
    }

    fn constImplementation(self: *const Store) ?*const StoreImpl {
        return @ptrCast(@alignCast(self._implementation orelse return null));
    }
};

const StoreImpl = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    canonical_path: []u8,
    lock_path: []u8,
    lease: std.Io.File,
    adapter: shovelerdb.Adapter,
    lifecycle: diagnostics.State,
    diagnostic: ?diagnostics.Diagnostic = null,
    store_id: u64,
    operation_id: u64 = 0,
    mutex: std.atomic.Mutex = .unlocked,
    faults: durability.Faults = .{},
    events: durability.EventLog = .{},
    checkpoint_count: usize = 0,
    discard_count: usize = 0,
    reopen_count: usize = 0,
    directory_stats: directory_sync.Stats = .{},
    receipt_issued: bool = false,

    fn mutate(self: *StoreImpl, operation: durability.WriteOperation) diagnostics.StoreError!durability.DurableReceipt {
        lock(&self.mutex);
        defer self.mutex.unlock();
        try self.requireReady();
        return self.runDurable(operation);
    }

    fn startupWrite(self: *StoreImpl, operation: durability.WriteOperation) diagnostics.StoreError!durability.DurableReceipt {
        lock(&self.mutex);
        defer self.mutex.unlock();
        try self.requireReady();

        self.resetOperation();
        self.lifecycle = .mutating;
        durability.begin(&self.adapter, self.faults) catch |err| {
            self.readyDiagnostic(.transaction_begin_failure, .transaction);
            return err;
        };
        self.events.append(.transaction_began);

        var statement_executor = durability.executor(&self.adapter);
        if (self.faults.callback) {
            durability.callbackFailed();
            return self.recoverFailedStartup(.callback_failure, .injected_fault);
        }
        operation.run(operation.context, &statement_executor) catch {
            durability.callbackFailed();
            return self.recoverFailedStartup(.callback_failure, .transaction);
        };
        self.events.append(.callback_succeeded);
        return self.finishDurability();
    }

    /// Closes without checkpointing. Uncertain or dirty work is never promoted
    /// to durable state by shutdown.
    fn shutdown(self: *StoreImpl) diagnostics.StoreError!void {
        lock(&self.mutex);
        defer self.mutex.unlock();

        self.adapter.close();
        self.lease.close(self.io);
        self.lifecycle = .closed;
        self.releaseOwnedPaths();
        if (self.faults.shutdown) {
            persistence_coverage.hit(.shutdown_failure);
            self.setDiagnostic(.shutdown_failure, .injected_fault);
            return diagnostics.StoreError.ShutdownFailed;
        }
    }

    fn runDurable(self: *StoreImpl, operation: durability.WriteOperation) diagnostics.StoreError!durability.DurableReceipt {
        self.resetOperation();
        self.lifecycle = .mutating;
        durability.begin(&self.adapter, self.faults) catch |err| {
            self.readyDiagnostic(.transaction_begin_failure, .transaction);
            return err;
        };
        self.events.append(.transaction_began);

        var statement_executor = durability.executor(&self.adapter);
        const callback_failed = self.faults.callback or blk: {
            operation.run(operation.context, &statement_executor) catch break :blk true;
            break :blk false;
        };
        if (callback_failed) {
            durability.callbackFailed();
            durability.rollback(&self.adapter, self.faults) catch |err| {
                self.lifecycle = .quarantined;
                self.setDiagnostic(.rollback_failure, .transaction);
                return err;
            };
            self.readyDiagnostic(.callback_failure, if (self.faults.callback) .injected_fault else .transaction);
            return diagnostics.StoreError.CallbackFailed;
        }
        self.events.append(.callback_succeeded);
        return self.finishDurability();
    }

    fn finishDurability(self: *StoreImpl) diagnostics.StoreError!durability.DurableReceipt {
        durability.commit(&self.adapter, self.faults) catch |err| {
            self.transitionUncertain(.commit_failure, .transaction);
            return err;
        };
        self.lifecycle = .committed_pending_checkpoint;
        self.events.append(.committed);

        durability.checkpoint(&self.adapter, self.faults) catch |err| {
            self.transitionUncertain(.checkpoint_failure, .persistence);
            return err;
        };
        self.checkpoint_count += 1;
        self.lifecycle = .checkpointed_pending_directory_sync;
        self.events.append(.checkpointed);

        directory_sync.syncParent(
            self.io,
            self.canonical_path,
            self.faults,
            &self.directory_stats,
        ) catch |err| {
            self.transitionUncertain(categoryForDirectoryError(err), causeForDirectoryError(err));
            return err;
        };
        self.lifecycle = .directory_synchronized;
        self.events.append(.directory_synchronized);
        self.operation_id += 1;
        const receipt = durability.DurableReceipt{
            .store_id = self.store_id,
            .operation_id = self.operation_id,
            .durability = .directory_synchronized,
        };
        self.receipt_issued = true;
        self.events.append(.receipt_issued);
        self.lifecycle = .ready;
        self.diagnostic = null;
        return receipt;
    }

    fn recoverFailedStartup(
        self: *StoreImpl,
        category: diagnostics.DiagnosticCategory,
        cause: diagnostics.Cause,
    ) diagnostics.StoreError!durability.DurableReceipt {
        self.adapter.close();
        self.discard_count += 1;
        if (self.faults.dirty_discard) {
            persistence_coverage.hit(.dirty_discard_failure);
            self.lifecycle = .quarantined;
            self.setDiagnostic(.dirty_discard_failure, .injected_fault);
            return diagnostics.StoreError.DirtyDiscardFailed;
        }

        if (self.faults.reopen) {
            persistence_coverage.hit(.reopen_failure);
            persistence_coverage.hit(.recovery_quarantine);
            self.lifecycle = .quarantined;
            self.setDiagnostic(.reopen_failure, .injected_fault);
            return diagnostics.StoreError.ReopenFailed;
        }
        self.adapter = shovelerdb.Adapter.open(self.allocator, self.canonical_path) catch {
            persistence_coverage.hit(.reopen_failure);
            persistence_coverage.hit(.recovery_quarantine);
            self.lifecycle = .quarantined;
            self.setDiagnostic(.reopen_failure, .persistence);
            return diagnostics.StoreError.ReopenFailed;
        };
        self.reopen_count += 1;
        self.lifecycle = .ready;
        self.setDiagnostic(category, cause);
        return diagnostics.StoreError.StartupWriteFailed;
    }

    fn requireReady(self: *StoreImpl) diagnostics.StoreError!void {
        switch (self.lifecycle) {
            .ready => return,
            .closed => return diagnostics.StoreError.StoreClosed,
            .uncertain, .quarantined => {
                persistence_coverage.hit(.quarantined_refusal);
                self.lifecycle = .quarantined;
                self.setDiagnostic(.quarantine, .persistence);
                return diagnostics.StoreError.StoreQuarantined;
            },
            else => {
                persistence_coverage.hit(.quarantined_refusal);
                self.lifecycle = .quarantined;
                self.setDiagnostic(.quarantine, .internal);
                return diagnostics.StoreError.StoreQuarantined;
            },
        }
    }

    fn transitionUncertain(
        self: *StoreImpl,
        category: diagnostics.DiagnosticCategory,
        cause: diagnostics.Cause,
    ) void {
        persistence_coverage.hit(.uncertain_transition);
        self.lifecycle = .uncertain;
        self.setDiagnostic(category, cause);
    }

    fn readyDiagnostic(
        self: *StoreImpl,
        category: diagnostics.DiagnosticCategory,
        cause: diagnostics.Cause,
    ) void {
        self.lifecycle = .ready;
        self.setDiagnostic(category, cause);
    }

    fn setDiagnostic(
        self: *StoreImpl,
        category: diagnostics.DiagnosticCategory,
        cause: diagnostics.Cause,
    ) void {
        self.diagnostic = .{
            .category = category,
            .store_id = self.store_id,
            .state = self.lifecycle,
            .cause = cause,
        };
    }

    fn resetOperation(self: *StoreImpl) void {
        self.events.reset();
        self.receipt_issued = false;
        self.diagnostic = null;
    }

    fn releaseOwnedPaths(self: *StoreImpl) void {
        self.allocator.free(self.canonical_path);
        self.allocator.free(self.lock_path);
    }
};

pub fn openWithFaults(
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
    faults: durability.Faults,
) diagnostics.StoreError!Store {
    const canonical_path = canonicalize(allocator, io, path, faults) catch |err| return err;
    errdefer allocator.free(canonical_path);
    const store_id = diagnostics.stableStoreId(canonical_path);
    const lock_path = std.fmt.allocPrint(allocator, "{s}.lock", .{canonical_path}) catch return diagnostics.StoreError.OutOfMemory;
    errdefer allocator.free(lock_path);

    if (faults.lease_acquire) {
        persistence_coverage.hit(.lease_acquire_failure);
        return diagnostics.StoreError.LeaseAcquireFailed;
    }
    const lease = std.Io.Dir.createFileAbsolute(io, lock_path, .{
        .read = true,
        .truncate = false,
        .lock = .exclusive,
        .lock_nonblocking = true,
    }) catch |err| switch (err) {
        error.WouldBlock => {
            persistence_coverage.hit(.lease_conflict);
            return diagnostics.StoreError.LeaseConflict;
        },
        else => {
            persistence_coverage.hit(.lease_acquire_failure);
            return diagnostics.StoreError.LeaseAcquireFailed;
        },
    };
    errdefer lease.close(io);

    if (faults.engine_open) {
        persistence_coverage.hit(.engine_open_failure);
        persistence_coverage.hit(.partial_open_cleanup);
        return diagnostics.StoreError.EngineOpenFailed;
    }
    var adapter = shovelerdb.Adapter.open(allocator, canonical_path) catch {
        persistence_coverage.hit(.engine_open_failure);
        persistence_coverage.hit(.partial_open_cleanup);
        return diagnostics.StoreError.EngineOpenFailed;
    };
    errdefer adapter.close();

    const implementation = allocator.create(StoreImpl) catch return diagnostics.StoreError.OutOfMemory;
    implementation.* = .{
        .allocator = allocator,
        .io = io,
        .canonical_path = canonical_path,
        .lock_path = lock_path,
        .lease = lease,
        .adapter = adapter,
        .lifecycle = .ready,
        .store_id = store_id,
        .faults = faults,
    };
    return .{
        ._implementation = implementation,
        ._terminal_state = .ready,
    };
}

fn canonicalize(
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
    faults: durability.Faults,
) diagnostics.StoreError![]u8 {
    if (faults.canonicalization or path.len == 0 or std.mem.indexOfScalar(u8, path, 0) != null) {
        persistence_coverage.hit(.canonicalization_failure);
        return diagnostics.StoreError.CanonicalizationFailed;
    }

    if (std.Io.Dir.realPathFileAlloc(.cwd(), io, path, allocator)) |resolved| {
        defer allocator.free(resolved);
        return allocator.dupe(u8, resolved) catch diagnostics.StoreError.OutOfMemory;
    } else |err| switch (err) {
        error.FileNotFound => {},
        else => {
            persistence_coverage.hit(.canonicalization_failure);
            return diagnostics.StoreError.CanonicalizationFailed;
        },
    }

    const basename = std.fs.path.basename(path);
    if (basename.len == 0 or std.mem.eql(u8, basename, ".") or std.mem.eql(u8, basename, "..")) {
        persistence_coverage.hit(.canonicalization_failure);
        return diagnostics.StoreError.CanonicalizationFailed;
    }
    const parent_path = std.fs.path.dirname(path) orelse ".";
    var parent = std.Io.Dir.openDir(.cwd(), io, parent_path, .{}) catch {
        persistence_coverage.hit(.canonicalization_failure);
        return diagnostics.StoreError.CanonicalizationFailed;
    };
    defer parent.close(io);
    var buffer: [std.fs.max_path_bytes]u8 = undefined;
    const len = parent.realPath(io, &buffer) catch {
        persistence_coverage.hit(.canonicalization_failure);
        return diagnostics.StoreError.CanonicalizationFailed;
    };
    return std.fs.path.join(allocator, &.{ buffer[0..len], basename }) catch diagnostics.StoreError.OutOfMemory;
}

fn categoryForDirectoryError(err: diagnostics.StoreError) diagnostics.DiagnosticCategory {
    return switch (err) {
        error.DirectoryOpenFailed => .directory_open_failure,
        error.DirectorySyncFailed => .directory_sync_failure,
        error.DirectoryCloseFailed => .directory_close_failure,
        error.UnsupportedDirectorySync => .unsupported_directory_sync,
        else => .directory_sync_failure,
    };
}

fn causeForDirectoryError(err: diagnostics.StoreError) diagnostics.Cause {
    return switch (err) {
        error.UnsupportedDirectorySync => .unsupported,
        else => .io,
    };
}

fn lock(mutex: *std.atomic.Mutex) void {
    while (!mutex.tryLock()) std.atomic.spinLoopHint();
}

pub fn setFaults(durable_store: *Store, faults: durability.Faults) void {
    const implementation = durable_store.implementation() orelse return;
    implementation.faults = faults;
}

pub fn checkpointCount(durable_store: *const Store) usize {
    return (durable_store.constImplementation() orelse return 0).checkpoint_count;
}

pub fn discardCount(durable_store: *const Store) usize {
    return (durable_store.constImplementation() orelse return 0).discard_count;
}

pub fn reopenCount(durable_store: *const Store) usize {
    return (durable_store.constImplementation() orelse return 0).reopen_count;
}

pub fn openDirectoryCount(durable_store: *const Store) usize {
    return (durable_store.constImplementation() orelse return 0).directory_stats.live_descriptors;
}

pub fn receiptIssued(durable_store: *const Store) bool {
    return (durable_store.constImplementation() orelse return false).receipt_issued;
}

pub fn events(durable_store: *const Store) []const durability.DurabilityEvent {
    return (durable_store.constImplementation() orelse return &.{}).events.slice();
}

pub fn rowCount(durable_store: *Store, comptime sql: [:0]const u8) diagnostics.StoreError!usize {
    const implementation = durable_store.implementation() orelse return diagnostics.StoreError.StoreClosed;
    lock(&implementation.mutex);
    defer implementation.mutex.unlock();
    try implementation.requireReady();
    var result = implementation.adapter.execute(implementation.allocator, sql) catch return diagnostics.StoreError.QueryFailed;
    defer result.deinit(implementation.allocator);
    return switch (result) {
        .rows => |rows| rows.rows.len,
        else => diagnostics.StoreError.QueryFailed,
    };
}
