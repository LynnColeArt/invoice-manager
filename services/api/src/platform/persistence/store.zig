const std = @import("std");
const shovelerdb = @import("shovelerdb_adapter");
const persistence_coverage = @import("persistence_coverage_probe");
const diagnostics = @import("diagnostics.zig");
const durability = @import("durability.zig");
const directory_sync = @import("directory_sync.zig");

/// Public store capability. The numeric tag is only a registry nonce; it is
/// never an address and cannot expose or forge implementation storage.
pub const Store = enum(u128) {
    _,

    pub fn open(
        allocator: std.mem.Allocator,
        io: std.Io,
        path: []const u8,
    ) diagnostics.StoreError!Store {
        return openWithFaults(allocator, io, path, .{});
    }

    pub fn state(self: *const Store) diagnostics.State {
        const admission = observe(self.*) catch return .closed;
        defer admission.release();
        return admission.implementation.stateSnapshot();
    }

    pub fn lastDiagnostic(self: *const Store) ?diagnostics.Diagnostic {
        if (observe(self.*)) |admission| {
            defer admission.release();
            return admission.implementation.diagnosticSnapshot();
        } else |_| {
            return tombstoneDiagnostic(self.*);
        }
    }

    pub fn mutate(self: *Store, operation: durability.WriteOperation) diagnostics.StoreError!durability.DurableReceipt {
        const admission = try admit(self.*);
        defer admission.release();
        return admission.implementation.mutate(operation);
    }

    pub fn startupWrite(self: *Store, operation: durability.StartupWriteOperation) diagnostics.StoreError!durability.DurableReceipt {
        const admission = try admit(self.*);
        defer admission.release();
        return admission.implementation.startupWrite(operation);
    }

    /// Runs one startup write only for storage that this Store created from an
    /// absent canonical path and only before any Store operation becomes durable.
    pub fn initializeFresh(self: *Store, operation: durability.StartupWriteOperation) diagnostics.StoreError!durability.DurableReceipt {
        const admission = try admit(self.*);
        defer admission.release();
        return admission.implementation.initializeFresh(operation);
    }

    /// Completes only checkpoint and directory synchronization for an already
    /// committed operation. It never invokes or replays an application callback.
    pub fn completeDurability(self: *Store) diagnostics.StoreError!durability.DurableReceipt {
        const admission = try admit(self.*);
        defer admission.release();
        return admission.implementation.completeDurability();
    }

    pub fn shutdown(self: *Store) diagnostics.StoreError!void {
        var waiter = ShutdownWaiter{};
        const action = beginClosing(self.*, &waiter) orelse return;
        switch (action) {
            .waiter => |slot| {
                waitForClosing(slot);
                const consumed = consumeClosing(slot, &waiter);
                waitForReclamation(&waiter, consumed.io);
                return terminalShutdownResult(consumed.outcome);
            },
            .archived => |outcome| return terminalShutdownResult(outcome),
            .leader => |closing| {
                waitForAdmissions(closing.slot, closing.implementation.io);

                const allocator = closing.implementation.allocator;
                const io = closing.implementation.io;
                var terminal_error: ?diagnostics.StoreError = null;
                closing.implementation.shutdown() catch |err| {
                    terminal_error = err;
                };
                const terminal_diagnostic = closing.implementation.diagnosticSnapshot();
                finalizeClosing(closing.slot, terminal_diagnostic, terminal_error);
                allocator.destroy(closing.implementation);
                retireClosing(closing.slot, allocator, io);
                if (terminal_error) |err| return err;
            },
        }
    }
};

const RegistrySlot = struct {
    next: ?*RegistrySlot = null,
    id: u128 = 0,
    implementation: ?*StoreImpl = null,
    active: usize = 0,
    closing: bool = false,
    close_complete: bool = false,
    waiters: usize = 0,
    consumed_waiters: usize = 0,
    waiter_head: ?*ShutdownWaiter = null,
    io: std.Io = undefined,
    terminal_diagnostic: ?diagnostics.Diagnostic = null,
    terminal_error: ?diagnostics.StoreError = null,
    shutdown_call_barrier: ?*durability.ShutdownCallBarrier = null,
};

var registry_mutex: std.atomic.Mutex = .unlocked;
var registry_head: ?*RegistrySlot = null;

const TerminalOutcome = struct {
    id: u128 = 0,
    diagnostic: ?diagnostics.Diagnostic = null,
    terminal_error: ?diagnostics.StoreError = null,
};

const ShutdownWaiter = struct {
    next: ?*ShutdownWaiter = null,
    consumed: bool = false,
    reclaimed: bool = false,
};

const ConsumedOutcome = struct {
    outcome: TerminalOutcome,
    io: std.Io,
};

const tombstone_capacity = 256;
var tombstones: [tombstone_capacity]TerminalOutcome = [_]TerminalOutcome{.{}} ** tombstone_capacity;
var tombstone_cursor: usize = 0;

const Admission = struct {
    slot: *RegistrySlot,
    implementation: *StoreImpl,

    fn release(self: Admission) void {
        lock(&registry_mutex);
        defer registry_mutex.unlock();
        std.debug.assert(self.slot.active > 0);
        self.slot.active -= 1;
    }
};

const Closing = struct {
    slot: *RegistrySlot,
    implementation: *StoreImpl,
};

const ClosingAction = union(enum) {
    leader: Closing,
    waiter: *RegistrySlot,
    archived: TerminalOutcome,
};

fn storeNonce(store: Store) ?u128 {
    const raw = @intFromEnum(store);
    if (raw == 0) return null;
    return raw;
}

fn register(implementation: *StoreImpl) diagnostics.StoreError!Store {
    const slot = implementation.allocator.create(RegistrySlot) catch
        return diagnostics.StoreError.OutOfMemory;
    errdefer implementation.allocator.destroy(slot);

    for (0..32) |_| {
        var nonce_bytes: [16]u8 = undefined;
        std.Io.randomSecure(implementation.io, &nonce_bytes) catch
            return diagnostics.StoreError.CapabilityGenerationFailed;
        var id: u128 = @bitCast(nonce_bytes);
        // Keep valid capabilities outside the trivially guessable usize range
        // while retaining 127 bits of secure entropy.
        id |= @as(u128, 1) << 127;

        lock(&registry_mutex);
        var collision = false;
        var current = registry_head;
        while (current) |registered| : (current = registered.next) {
            if (registered.id == id) collision = true;
        }
        if (tombstoneOutcomeLocked(id) != null) collision = true;
        if (collision) {
            registry_mutex.unlock();
            continue;
        }
        slot.* = .{
            .next = registry_head,
            .id = id,
            .implementation = implementation,
            .io = implementation.io,
            .shutdown_call_barrier = implementation.faults.shutdown_call_barrier,
        };
        registry_head = slot;
        registry_mutex.unlock();
        return @enumFromInt(id);
    }
    return diagnostics.StoreError.CapabilityGenerationFailed;
}

fn admit(store: Store) diagnostics.StoreError!Admission {
    const id = storeNonce(store) orelse return diagnostics.StoreError.StoreClosed;
    lock(&registry_mutex);
    defer registry_mutex.unlock();
    var current = registry_head;
    while (current) |slot| : (current = slot.next) {
        if (slot.id != id or slot.implementation == null) continue;
        if (slot.closing) return diagnostics.StoreError.StoreClosed;
        slot.active += 1;
        return .{ .slot = slot, .implementation = slot.implementation.? };
    }
    return diagnostics.StoreError.StoreClosed;
}

fn observe(store: Store) diagnostics.StoreError!Admission {
    const id = storeNonce(store) orelse return diagnostics.StoreError.StoreClosed;
    lock(&registry_mutex);
    defer registry_mutex.unlock();
    var current = registry_head;
    while (current) |slot| : (current = slot.next) {
        if (slot.id != id or slot.implementation == null) continue;
        if (slot.closing) return diagnostics.StoreError.StoreClosed;
        slot.active += 1;
        return .{ .slot = slot, .implementation = slot.implementation.? };
    }
    return diagnostics.StoreError.StoreClosed;
}

fn tombstoneDiagnostic(store: Store) ?diagnostics.Diagnostic {
    const id = storeNonce(store) orelse return null;
    lock(&registry_mutex);
    defer registry_mutex.unlock();
    var current = registry_head;
    while (current) |slot| : (current = slot.next) {
        if (slot.id == id and slot.close_complete) return slot.terminal_diagnostic;
    }
    return if (tombstoneOutcomeLocked(id)) |outcome| outcome.diagnostic else null;
}

fn beginClosing(store: Store, waiter: *ShutdownWaiter) ?ClosingAction {
    const id = storeNonce(store) orelse return null;
    lock(&registry_mutex);
    defer registry_mutex.unlock();
    var current = registry_head;
    while (current) |slot| : (current = slot.next) {
        if (slot.id != id) continue;
        if (slot.close_complete) {
            if (slot.shutdown_call_barrier) |barrier| barrier.markCaller();
            enrollWaiter(slot, waiter);
            return .{ .waiter = slot };
        }
        if (slot.implementation == null) return null;
        if (slot.shutdown_call_barrier) |barrier| barrier.markCaller();
        if (slot.closing) {
            enrollWaiter(slot, waiter);
            return .{ .waiter = slot };
        }
        slot.closing = true;
        return .{ .leader = .{ .slot = slot, .implementation = slot.implementation.? } };
    }
    if (tombstoneOutcomeLocked(id)) |outcome| return .{ .archived = outcome };
    return null;
}

fn enrollWaiter(slot: *RegistrySlot, waiter: *ShutdownWaiter) void {
    waiter.next = slot.waiter_head;
    slot.waiter_head = waiter;
    slot.waiters += 1;
}

fn waitForClosing(slot: *RegistrySlot) void {
    const pause = std.Io.Clock.Duration{ .raw = .fromMilliseconds(1), .clock = .awake };
    while (true) {
        lock(&registry_mutex);
        const complete = slot.close_complete;
        registry_mutex.unlock();
        if (complete) return;
        pause.sleep(slot.io) catch {};
    }
}

fn consumeClosing(slot: *RegistrySlot, waiter: *ShutdownWaiter) ConsumedOutcome {
    lock(&registry_mutex);
    defer registry_mutex.unlock();
    std.debug.assert(slot.close_complete);
    std.debug.assert(slot.waiters > slot.consumed_waiters);
    std.debug.assert(!waiter.consumed);
    const outcome = TerminalOutcome{
        .id = slot.id,
        .diagnostic = slot.terminal_diagnostic,
        .terminal_error = slot.terminal_error,
    };
    waiter.consumed = true;
    slot.consumed_waiters += 1;
    return .{ .outcome = outcome, .io = slot.io };
}

fn waitForReclamation(waiter: *ShutdownWaiter, io: std.Io) void {
    const pause = std.Io.Clock.Duration{ .raw = .fromMilliseconds(1), .clock = .awake };
    while (!@atomicLoad(bool, &waiter.reclaimed, .acquire)) {
        pause.sleep(io) catch {};
    }
}

fn terminalShutdownResult(outcome: TerminalOutcome) diagnostics.StoreError!void {
    if (outcome.terminal_error) |err| return err;
}

fn waitForAdmissions(slot: *RegistrySlot, io: std.Io) void {
    const pause = std.Io.Clock.Duration{ .raw = .fromMilliseconds(1), .clock = .awake };
    while (true) {
        lock(&registry_mutex);
        const active = slot.active;
        registry_mutex.unlock();
        if (active == 0) return;
        pause.sleep(io) catch {};
    }
}

fn finalizeClosing(
    slot: *RegistrySlot,
    terminal_diagnostic: ?diagnostics.Diagnostic,
    terminal_error: ?diagnostics.StoreError,
) void {
    lock(&registry_mutex);
    defer registry_mutex.unlock();
    std.debug.assert(slot.active == 0);
    slot.implementation = null;
    slot.closing = true;
    slot.terminal_diagnostic = terminal_diagnostic;
    slot.terminal_error = terminal_error;
    slot.close_complete = true;
}

fn retireClosing(slot: *RegistrySlot, allocator: std.mem.Allocator, io: std.Io) void {
    const pause = std.Io.Clock.Duration{ .raw = .fromMilliseconds(1), .clock = .awake };
    while (true) {
        lock(&registry_mutex);
        if (slot.waiters == slot.consumed_waiters) {
            const outcome = TerminalOutcome{
                .id = slot.id,
                .diagnostic = slot.terminal_diagnostic,
                .terminal_error = slot.terminal_error,
            };
            const waiter_head = slot.waiter_head;
            const shutdown_call_barrier = slot.shutdown_call_barrier;
            removeRegistrySlotLocked(slot);
            allocator.destroy(slot);
            archiveTombstoneLocked(outcome);
            if (shutdown_call_barrier) |barrier| barrier.markReclaimed();
            var current_waiter = waiter_head;
            while (current_waiter) |value| {
                const next = value.next;
                @atomicStore(bool, &value.reclaimed, true, .release);
                current_waiter = next;
            }
            registry_mutex.unlock();
            return;
        }
        registry_mutex.unlock();
        pause.sleep(io) catch {};
    }
}

fn removeRegistrySlotLocked(target: *RegistrySlot) void {
    var previous: ?*RegistrySlot = null;
    var current = registry_head;
    while (current) |slot| : (current = slot.next) {
        if (slot == target) {
            if (previous) |value| {
                value.next = slot.next;
            } else {
                registry_head = slot.next;
            }
            return;
        }
        previous = slot;
    }
    unreachable;
}

fn tombstoneOutcomeLocked(id: u128) ?TerminalOutcome {
    for (&tombstones) |*outcome| {
        if (outcome.id == id) return outcome.*;
    }
    return null;
}

fn archiveTombstoneLocked(outcome: TerminalOutcome) void {
    tombstones[tombstone_cursor] = outcome;
    tombstone_cursor = (tombstone_cursor + 1) % tombstone_capacity;
}

const StoreImpl = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    canonical_path: []u8,
    lock_path: []u8,
    lease: std.Io.File,
    inode_lease: std.Io.File,
    adapter: shovelerdb.Adapter,
    lifecycle: diagnostics.State,
    diagnostic: ?diagnostics.Diagnostic = null,
    store_id: u64,
    operation_id: u64 = 0,
    mutex: std.atomic.Mutex = .unlocked,
    metadata_mutex: std.atomic.Mutex = .unlocked,
    faults: durability.Faults = .{},
    events: durability.EventLog = .{},
    checkpoint_count: usize = 0,
    discard_count: usize = 0,
    reopen_count: usize = 0,
    directory_stats: directory_sync.Stats = .{},
    receipt_issued: bool = false,
    fresh_origin: bool,
    durable_operation_completed: bool = false,

    fn mutate(self: *StoreImpl, operation: durability.WriteOperation) diagnostics.StoreError!durability.DurableReceipt {
        lock(&self.mutex);
        defer self.mutex.unlock();
        try self.requireReady();
        return self.runDurable(operation);
    }

    fn startupWrite(self: *StoreImpl, operation: durability.StartupWriteOperation) diagnostics.StoreError!durability.DurableReceipt {
        lock(&self.mutex);
        defer self.mutex.unlock();
        try self.requireReady();

        return self.startupWriteLocked(operation);
    }

    fn initializeFresh(self: *StoreImpl, operation: durability.StartupWriteOperation) diagnostics.StoreError!durability.DurableReceipt {
        lock(&self.mutex);
        defer self.mutex.unlock();
        try self.requireReady();
        if (!self.fresh_origin or self.durable_operation_completed) {
            self.setStateAndDiagnostic(.ready, .not_fresh, .internal);
            return diagnostics.StoreError.NotFresh;
        }

        return self.startupWriteLocked(operation);
    }

    fn startupWriteLocked(self: *StoreImpl, operation: durability.StartupWriteOperation) diagnostics.StoreError!durability.DurableReceipt {
        self.resetOperation();
        self.setState(.mutating);
        durability.begin(&self.adapter, self.faults) catch |err| {
            self.readyDiagnostic(.transaction_begin_failure, .transaction);
            return err;
        };
        self.events.append(.transaction_began);
        var executor_scope = durability.scopedStartupExecutor(self.io, &self.adapter, self.faults) catch {
            durability.callbackFailed();
            return self.recoverFailedStartup(.callback_failure, .allocation);
        };

        const statement_executor = durability.startupExecutor(&executor_scope);
        if (self.faults.callback) {
            executor_scope.close();
            durability.callbackFailed();
            return self.recoverFailedStartup(.callback_failure, .injected_fault);
        }
        operation.run(operation.context, statement_executor) catch {
            executor_scope.close();
            durability.callbackFailed();
            return self.recoverFailedStartup(.callback_failure, .transaction);
        };
        executor_scope.close();
        self.events.append(.callback_succeeded);
        return self.finishDurability();
    }

    fn completeDurability(self: *StoreImpl) diagnostics.StoreError!durability.DurableReceipt {
        lock(&self.mutex);
        defer self.mutex.unlock();

        const state = self.stateSnapshot();
        if (state == .committed_pending_checkpoint) return self.finishCheckpointAndSync();
        if (state == .checkpointed_pending_directory_sync) return self.finishDirectorySync();
        if (state != .uncertain and state != .quarantined) {
            return diagnostics.StoreError.DurabilityCompletionUnavailable;
        }

        const diagnostic = self.diagnosticSnapshot() orelse
            return diagnostics.StoreError.DurabilityCompletionUnavailable;
        return switch (diagnostic.category) {
            .checkpoint_failure => self.finishCheckpointAndSync(),
            .directory_open_failure,
            .directory_sync_failure,
            .directory_close_failure,
            .unsupported_directory_sync,
            => self.finishDirectorySync(),
            .lease_acquire_failure,
            .lease_conflict,
            => self.finishInodeLeaseAndDirectorySync(),
            else => diagnostics.StoreError.DurabilityCompletionUnavailable,
        };
    }

    /// Closes without checkpointing. Uncertain or dirty work is never promoted
    /// to durable state by shutdown.
    fn shutdown(self: *StoreImpl) diagnostics.StoreError!void {
        lock(&self.mutex);
        defer self.mutex.unlock();

        self.adapter.close();
        self.inode_lease.close(self.io);
        self.lease.close(self.io);
        self.setState(.closed);
        self.releaseOwnedPaths();
        if (self.faults.shutdown) {
            persistence_coverage.hit(.shutdown_failure);
            self.setDiagnosticIfAbsent(.shutdown_failure, .injected_fault);
            return diagnostics.StoreError.ShutdownFailed;
        }
    }

    fn runDurable(self: *StoreImpl, operation: durability.WriteOperation) diagnostics.StoreError!durability.DurableReceipt {
        self.resetOperation();
        self.setState(.mutating);
        durability.begin(&self.adapter, self.faults) catch |err| {
            self.readyDiagnostic(.transaction_begin_failure, .transaction);
            return err;
        };
        self.events.append(.transaction_began);
        var executor_scope = durability.scopedExecutor(self.io, &self.adapter, self.faults) catch |err| {
            durability.callbackFailed();
            durability.rollback(&self.adapter, self.faults) catch |rollback_err| {
                self.setStateAndDiagnostic(.quarantined, .rollback_failure, .transaction);
                return rollback_err;
            };
            self.readyDiagnostic(.callback_failure, .allocation);
            return err;
        };

        const statement_executor = durability.executor(&executor_scope);
        if (self.faults.callback) {
            executor_scope.close();
            durability.callbackFailed();
            durability.rollback(&self.adapter, self.faults) catch |err| {
                self.setStateAndDiagnostic(.quarantined, .rollback_failure, .transaction);
                return err;
            };
            self.readyDiagnostic(.callback_failure, .injected_fault);
            return diagnostics.StoreError.CallbackFailed;
        }
        operation.run(operation.context, statement_executor) catch {
            executor_scope.close();
            durability.callbackFailed();
            durability.rollback(&self.adapter, self.faults) catch |err| {
                self.setStateAndDiagnostic(.quarantined, .rollback_failure, .transaction);
                return err;
            };
            self.readyDiagnostic(.callback_failure, .transaction);
            return diagnostics.StoreError.CallbackFailed;
        };
        executor_scope.close();
        self.events.append(.callback_succeeded);
        return self.finishDurability();
    }

    fn finishDurability(self: *StoreImpl) diagnostics.StoreError!durability.DurableReceipt {
        durability.commit(&self.adapter, self.faults) catch |err| {
            self.transitionUncertain(.commit_failure, .transaction);
            return err;
        };
        self.setState(.committed_pending_checkpoint);
        self.events.append(.committed);

        return self.finishCheckpointAndSync();
    }

    fn finishCheckpointAndSync(self: *StoreImpl) diagnostics.StoreError!durability.DurableReceipt {
        durability.checkpoint(&self.adapter, self.faults) catch |err| {
            self.transitionUncertain(.checkpoint_failure, .persistence);
            return err;
        };
        self.checkpoint_count += 1;
        self.setState(.checkpointed_pending_directory_sync);
        self.events.append(.checkpointed);

        return self.finishInodeLeaseAndDirectorySync();
    }

    fn finishInodeLeaseAndDirectorySync(self: *StoreImpl) diagnostics.StoreError!durability.DurableReceipt {
        self.refreshInodeLease() catch |err| {
            self.transitionUncertain(categoryForLeaseError(err), causeForLeaseError(err));
            return err;
        };
        return self.finishDirectorySync();
    }

    fn finishDirectorySync(self: *StoreImpl) diagnostics.StoreError!durability.DurableReceipt {
        directory_sync.syncParent(
            self.io,
            self.canonical_path,
            self.faults,
            &self.directory_stats,
        ) catch |err| {
            self.transitionUncertain(categoryForDirectoryError(err), causeForDirectoryError(err));
            return err;
        };
        self.setState(.directory_synchronized);
        self.events.append(.directory_synchronized);
        self.operation_id += 1;
        const receipt = durability.DurableReceipt{
            .store_id = self.store_id,
            .operation_id = self.operation_id,
            .durability = .directory_synchronized,
        };
        self.receipt_issued = true;
        self.durable_operation_completed = true;
        self.events.append(.receipt_issued);
        self.setReadyWithoutDiagnostic();
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
            self.setStateAndDiagnostic(.quarantined, .dirty_discard_failure, .injected_fault);
            return diagnostics.StoreError.DirtyDiscardFailed;
        }

        if (self.faults.reopen) {
            persistence_coverage.hit(.reopen_failure);
            persistence_coverage.hit(.recovery_quarantine);
            self.setStateAndDiagnostic(.quarantined, .reopen_failure, .injected_fault);
            return diagnostics.StoreError.ReopenFailed;
        }
        self.adapter = shovelerdb.Adapter.open(self.allocator, self.canonical_path) catch {
            persistence_coverage.hit(.reopen_failure);
            persistence_coverage.hit(.recovery_quarantine);
            self.setStateAndDiagnostic(.quarantined, .reopen_failure, .persistence);
            return diagnostics.StoreError.ReopenFailed;
        };
        self.reopen_count += 1;
        self.setStateAndDiagnostic(.ready, category, cause);
        return diagnostics.StoreError.StartupWriteFailed;
    }

    fn requireReady(self: *StoreImpl) diagnostics.StoreError!void {
        switch (self.stateSnapshot()) {
            .ready => return,
            .closed => return diagnostics.StoreError.StoreClosed,
            .uncertain, .quarantined => {
                persistence_coverage.hit(.quarantined_refusal);
                self.quarantinePreservingCause(.persistence);
                return diagnostics.StoreError.StoreQuarantined;
            },
            else => {
                persistence_coverage.hit(.quarantined_refusal);
                self.quarantinePreservingCause(.internal);
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
        self.setStateAndDiagnostic(.uncertain, category, cause);
    }

    fn readyDiagnostic(
        self: *StoreImpl,
        category: diagnostics.DiagnosticCategory,
        cause: diagnostics.Cause,
    ) void {
        self.setStateAndDiagnostic(.ready, category, cause);
    }

    fn resetOperation(self: *StoreImpl) void {
        self.events.reset();
        self.receipt_issued = false;
        lock(&self.metadata_mutex);
        defer self.metadata_mutex.unlock();
        self.diagnostic = null;
    }

    fn stateSnapshot(self: *const StoreImpl) diagnostics.State {
        const mutable: *StoreImpl = @constCast(self);
        lock(&mutable.metadata_mutex);
        defer mutable.metadata_mutex.unlock();
        return mutable.lifecycle;
    }

    fn diagnosticSnapshot(self: *const StoreImpl) ?diagnostics.Diagnostic {
        const mutable: *StoreImpl = @constCast(self);
        lock(&mutable.metadata_mutex);
        defer mutable.metadata_mutex.unlock();
        return mutable.diagnostic;
    }

    fn setState(self: *StoreImpl, state: diagnostics.State) void {
        lock(&self.metadata_mutex);
        defer self.metadata_mutex.unlock();
        self.lifecycle = state;
    }

    fn setStateAndDiagnostic(
        self: *StoreImpl,
        state: diagnostics.State,
        category: diagnostics.DiagnosticCategory,
        cause: diagnostics.Cause,
    ) void {
        lock(&self.metadata_mutex);
        defer self.metadata_mutex.unlock();
        self.lifecycle = state;
        self.diagnostic = .{
            .category = category,
            .store_id = self.store_id,
            .state = state,
            .cause = cause,
        };
    }

    fn setReadyWithoutDiagnostic(self: *StoreImpl) void {
        lock(&self.metadata_mutex);
        defer self.metadata_mutex.unlock();
        self.lifecycle = .ready;
        self.diagnostic = null;
    }

    fn quarantinePreservingCause(self: *StoreImpl, fallback_cause: diagnostics.Cause) void {
        lock(&self.metadata_mutex);
        defer self.metadata_mutex.unlock();
        self.lifecycle = .quarantined;
        if (self.diagnostic == null) {
            self.diagnostic = .{
                .category = .quarantine,
                .store_id = self.store_id,
                .state = .quarantined,
                .cause = fallback_cause,
            };
        }
    }

    fn setDiagnosticIfAbsent(
        self: *StoreImpl,
        category: diagnostics.DiagnosticCategory,
        cause: diagnostics.Cause,
    ) void {
        lock(&self.metadata_mutex);
        defer self.metadata_mutex.unlock();
        if (self.diagnostic == null) {
            self.diagnostic = .{
                .category = category,
                .store_id = self.store_id,
                .state = self.lifecycle,
                .cause = cause,
            };
        }
    }

    fn releaseOwnedPaths(self: *StoreImpl) void {
        self.allocator.free(self.canonical_path);
        self.allocator.free(self.lock_path);
    }

    fn refreshInodeLease(self: *StoreImpl) diagnostics.StoreError!void {
        const current = std.Io.Dir.openFileAbsolute(self.io, self.canonical_path, .{
            .allow_directory = false,
        }) catch return diagnostics.StoreError.LeaseAcquireFailed;
        const current_stat = current.stat(self.io) catch {
            current.close(self.io);
            return diagnostics.StoreError.LeaseAcquireFailed;
        };
        current.close(self.io);
        const held_stat = self.inode_lease.stat(self.io) catch
            return diagnostics.StoreError.LeaseAcquireFailed;
        if (current_stat.inode == held_stat.inode) return;

        const replacement = try acquireInodeLease(self.io, self.canonical_path, self.faults, false);
        self.inode_lease.close(self.io);
        self.inode_lease = replacement;
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
    try rejectHardLinkedFile(io, canonical_path, faults);
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
    const fresh_origin = canonicalPathAbsent(io, canonical_path);
    var adapter = shovelerdb.Adapter.open(allocator, canonical_path) catch {
        persistence_coverage.hit(.engine_open_failure);
        persistence_coverage.hit(.partial_open_cleanup);
        return diagnostics.StoreError.EngineOpenFailed;
    };
    errdefer adapter.close();
    const inode_lease = try acquireInodeLease(io, canonical_path, faults, true);
    errdefer inode_lease.close(io);

    const implementation = allocator.create(StoreImpl) catch return diagnostics.StoreError.OutOfMemory;
    errdefer allocator.destroy(implementation);
    implementation.* = .{
        .allocator = allocator,
        .io = io,
        .canonical_path = canonical_path,
        .lock_path = lock_path,
        .lease = lease,
        .inode_lease = inode_lease,
        .adapter = adapter,
        .lifecycle = .ready,
        .store_id = store_id,
        .faults = faults,
        .fresh_origin = fresh_origin,
    };
    if (faults.registration) {
        persistence_coverage.hit(.partial_open_cleanup);
        return diagnostics.StoreError.OutOfMemory;
    }
    return register(implementation);
}

fn canonicalPathAbsent(io: std.Io, canonical_path: []const u8) bool {
    const file = std.Io.Dir.openFileAbsolute(io, canonical_path, .{
        .allow_directory = false,
    }) catch |err| switch (err) {
        error.FileNotFound => return true,
        else => return false,
    };
    file.close(io);
    return false;
}

fn rejectHardLinkedFile(
    io: std.Io,
    canonical_path: []const u8,
    _: durability.Faults,
) diagnostics.StoreError!void {
    const file = std.Io.Dir.openFile(.cwd(), io, canonical_path, .{}) catch |err| switch (err) {
        error.FileNotFound => return,
        else => {
            persistence_coverage.hit(.lease_acquire_failure);
            return diagnostics.StoreError.LeaseAcquireFailed;
        },
    };
    defer file.close(io);
    const stat = file.stat(io) catch {
        persistence_coverage.hit(.lease_acquire_failure);
        return diagnostics.StoreError.LeaseAcquireFailed;
    };
    if (stat.kind == .file and stat.nlink > 1) {
        persistence_coverage.hit(.lease_conflict);
        return diagnostics.StoreError.LeaseConflict;
    }
}

fn acquireInodeLease(
    io: std.Io,
    canonical_path: []const u8,
    faults: durability.Faults,
    partial_open: bool,
) diagnostics.StoreError!std.Io.File {
    if (faults.identity_inspection) {
        persistence_coverage.hit(.lease_acquire_failure);
        if (partial_open) persistence_coverage.hit(.partial_open_cleanup);
        return diagnostics.StoreError.LeaseAcquireFailed;
    }
    return std.Io.Dir.openFileAbsolute(io, canonical_path, .{
        .allow_directory = false,
        .lock = .exclusive,
        .lock_nonblocking = true,
    }) catch |err| switch (err) {
        error.WouldBlock => {
            persistence_coverage.hit(.lease_conflict);
            if (partial_open) persistence_coverage.hit(.partial_open_cleanup);
            return diagnostics.StoreError.LeaseConflict;
        },
        else => {
            persistence_coverage.hit(.lease_acquire_failure);
            if (partial_open) persistence_coverage.hit(.partial_open_cleanup);
            return diagnostics.StoreError.LeaseAcquireFailed;
        },
    };
}

fn categoryForLeaseError(err: diagnostics.StoreError) diagnostics.DiagnosticCategory {
    return switch (err) {
        error.LeaseConflict => .lease_conflict,
        else => .lease_acquire_failure,
    };
}

fn causeForLeaseError(err: diagnostics.StoreError) diagnostics.Cause {
    return switch (err) {
        error.LeaseConflict => .resource_busy,
        else => .io,
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
    const admission = admit(durable_store.*) catch return;
    defer admission.release();
    lock(&admission.implementation.mutex);
    defer admission.implementation.mutex.unlock();
    admission.implementation.faults = faults;
}

pub fn checkpointCount(durable_store: *const Store) usize {
    const admission = admit(durable_store.*) catch return 0;
    defer admission.release();
    lock(&admission.implementation.mutex);
    defer admission.implementation.mutex.unlock();
    return admission.implementation.checkpoint_count;
}

pub fn discardCount(durable_store: *const Store) usize {
    const admission = admit(durable_store.*) catch return 0;
    defer admission.release();
    lock(&admission.implementation.mutex);
    defer admission.implementation.mutex.unlock();
    return admission.implementation.discard_count;
}

pub fn reopenCount(durable_store: *const Store) usize {
    const admission = admit(durable_store.*) catch return 0;
    defer admission.release();
    lock(&admission.implementation.mutex);
    defer admission.implementation.mutex.unlock();
    return admission.implementation.reopen_count;
}

pub fn openDirectoryCount(durable_store: *const Store) usize {
    const admission = admit(durable_store.*) catch return 0;
    defer admission.release();
    lock(&admission.implementation.mutex);
    defer admission.implementation.mutex.unlock();
    return admission.implementation.directory_stats.live_descriptors;
}

pub fn receiptIssued(durable_store: *const Store) bool {
    const admission = admit(durable_store.*) catch return false;
    defer admission.release();
    lock(&admission.implementation.mutex);
    defer admission.implementation.mutex.unlock();
    return admission.implementation.receipt_issued;
}

pub fn events(durable_store: *const Store) durability.EventSnapshot {
    const admission = admit(durable_store.*) catch return .{ .buffer = undefined, .len = 0 };
    defer admission.release();
    lock(&admission.implementation.mutex);
    defer admission.implementation.mutex.unlock();
    return admission.implementation.events.snapshot();
}

pub fn rowCount(durable_store: *Store, comptime sql: [:0]const u8) diagnostics.StoreError!usize {
    const admission = try admit(durable_store.*);
    defer admission.release();
    const implementation = admission.implementation;
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
