const std = @import("std");
const shovelerdb = @import("shovelerdb_adapter");
const persistence_coverage = @import("persistence_coverage_probe");
const diagnostics = @import("diagnostics.zig");

pub const State = diagnostics.State;
pub const StoreError = diagnostics.StoreError;

pub const DurableReceipt = struct {
    store_id: u64,
    operation_id: u64,
    durability: State,
};

pub const StatementResult = union(enum) {
    empty,
    mutation_count: u64,
    row_count: usize,
};

/// Application-neutral view of one copied result value. Any slice is valid
/// only for the duration of its row visitor call.
pub const RowValue = union(enum) {
    null_value,
    integer: i64,
    float: f64,
    boolean: bool,
    text: []const u8,
    blob: []const u8,
    vector_f32: []const f32,
};

/// Scoped, adapter-opaque access to one copied query row.
pub const RowView = opaque {
    pub fn len(self: *const RowView) usize {
        return ownedRow(self).values.len;
    }

    pub fn value(self: *const RowView, index: usize) StoreError!RowValue {
        const row = ownedRow(self);
        if (index >= row.values.len) return StoreError.RowIndexOutOfBounds;
        return neutralValue(row.values[index]);
    }
};

pub const RowVisitor = struct {
    context: *anyopaque,
    visit: *const fn (*anyopaque, *const RowView) anyerror!void,
};

/// A value-token capability for reviewed statements. The token is a secure
/// nonce, never an address, and every method acquires a live registry admission
/// for the complete adapter call.
pub const Executor = enum(u128) {
    _,

    pub fn execute(self: Executor, comptime sql: [:0]const u8) StoreError!StatementResult {
        const admission = try admitExecutor(@intFromEnum(self), .normal);
        defer admission.release();
        admission.pauseAfterAdmission();
        return executeReviewed(admission.adapter, sql);
    }

    pub fn executeText(
        self: Executor,
        comptime prefix: []const u8,
        text: []const u8,
        comptime suffix: []const u8,
    ) StoreError!StatementResult {
        const admission = try admitExecutor(@intFromEnum(self), .normal);
        defer admission.release();
        admission.pauseAfterAdmission();
        return executeOneText(admission.adapter, prefix, text, suffix);
    }

    pub fn executeBound(
        self: Executor,
        comptime fragments: []const []const u8,
        values: []const []const u8,
    ) StoreError!StatementResult {
        const admission = try admitExecutor(@intFromEnum(self), .normal);
        defer admission.release();
        admission.pauseAfterAdmission();
        return executeBoundValues(admission.adapter, fragments, values);
    }

    pub fn query(
        self: Executor,
        comptime sql: [:0]const u8,
        visitor: RowVisitor,
    ) anyerror!usize {
        const admission = try admitExecutor(@intFromEnum(self), .normal);
        defer admission.release();
        admission.pauseAfterAdmission();
        return queryReviewed(admission.adapter, sql, visitor);
    }

    pub fn queryBound(
        self: Executor,
        comptime fragments: []const []const u8,
        values: []const []const u8,
        visitor: RowVisitor,
    ) anyerror!usize {
        const admission = try admitExecutor(@intFromEnum(self), .normal);
        defer admission.release();
        admission.pauseAfterAdmission();
        return queryBoundValues(admission.adapter, fragments, values, visitor);
    }
};

/// Startup-only capability. It retains the reviewed and bound operations, and
/// uniquely permits one exact runtime migration script supplied by discovery.
pub const StartupExecutor = enum(u128) {
    _,

    pub fn execute(self: StartupExecutor, comptime sql: [:0]const u8) StoreError!StatementResult {
        const admission = try admitExecutor(@intFromEnum(self), .startup);
        defer admission.release();
        admission.pauseAfterAdmission();
        return executeReviewed(admission.adapter, sql);
    }

    pub fn executeText(
        self: StartupExecutor,
        comptime prefix: []const u8,
        text: []const u8,
        comptime suffix: []const u8,
    ) StoreError!StatementResult {
        const admission = try admitExecutor(@intFromEnum(self), .startup);
        defer admission.release();
        admission.pauseAfterAdmission();
        return executeOneText(admission.adapter, prefix, text, suffix);
    }

    pub fn executeBound(
        self: StartupExecutor,
        comptime fragments: []const []const u8,
        values: []const []const u8,
    ) StoreError!StatementResult {
        const admission = try admitExecutor(@intFromEnum(self), .startup);
        defer admission.release();
        admission.pauseAfterAdmission();
        return executeBoundValues(admission.adapter, fragments, values);
    }

    pub fn executeScript(self: StartupExecutor, script: []const u8) StoreError!StatementResult {
        const admission = try admitExecutor(@intFromEnum(self), .startup);
        defer admission.release();
        admission.pauseAfterAdmission();
        var result = admission.adapter.executeScript(admission.adapter.allocator, script) catch |err| return statementError(err);
        defer result.deinit(admission.adapter.allocator);
        return neutralResult(result);
    }

    pub fn query(
        self: StartupExecutor,
        comptime sql: [:0]const u8,
        visitor: RowVisitor,
    ) anyerror!usize {
        const admission = try admitExecutor(@intFromEnum(self), .startup);
        defer admission.release();
        admission.pauseAfterAdmission();
        return queryReviewed(admission.adapter, sql, visitor);
    }

    pub fn queryBound(
        self: StartupExecutor,
        comptime fragments: []const []const u8,
        values: []const []const u8,
        visitor: RowVisitor,
    ) anyerror!usize {
        const admission = try admitExecutor(@intFromEnum(self), .startup);
        defer admission.release();
        admission.pauseAfterAdmission();
        return queryBoundValues(admission.adapter, fragments, values, visitor);
    }
};

/// A write callback and its opaque application context. This keeps the store
/// implementation monomorphic while exposing only the capability-limited
/// executor at the callback boundary.
pub const WriteOperation = struct {
    context: *anyopaque,
    run: *const fn (*anyopaque, Executor) anyerror!void,
};

pub const StartupWriteOperation = struct {
    context: *anyopaque,
    run: *const fn (*anyopaque, StartupExecutor) anyerror!void,
};

pub const DurabilityEvent = enum {
    transaction_began,
    callback_succeeded,
    committed,
    checkpointed,
    directory_synchronized,
    receipt_issued,
};

pub const EventLog = struct {
    buffer: [8]DurabilityEvent = undefined,
    len: usize = 0,

    pub fn reset(self: *EventLog) void {
        self.len = 0;
    }

    pub fn append(self: *EventLog, event: DurabilityEvent) void {
        std.debug.assert(self.len < self.buffer.len);
        self.buffer[self.len] = event;
        self.len += 1;
    }

    pub fn slice(self: *const EventLog) []const DurabilityEvent {
        return self.buffer[0..self.len];
    }

    pub fn snapshot(self: *const EventLog) EventSnapshot {
        return .{ .buffer = self.buffer, .len = self.len };
    }
};

pub const EventSnapshot = struct {
    buffer: [8]DurabilityEvent,
    len: usize,

    pub fn slice(self: *const EventSnapshot) []const DurabilityEvent {
        return self.buffer[0..self.len];
    }
};

pub const ExecutorCallBarrier = struct {
    admitted: bool = false,
    closing: bool = false,
    released: bool = false,

    pub fn hasAdmitted(self: *ExecutorCallBarrier) bool {
        return @atomicLoad(bool, &self.admitted, .acquire);
    }

    pub fn hasClosing(self: *ExecutorCallBarrier) bool {
        return @atomicLoad(bool, &self.closing, .acquire);
    }

    pub fn allow(self: *ExecutorCallBarrier) void {
        @atomicStore(bool, &self.released, true, .release);
    }

    fn markAdmitted(self: *ExecutorCallBarrier) void {
        @atomicStore(bool, &self.admitted, true, .release);
    }

    fn markClosing(self: *ExecutorCallBarrier) void {
        @atomicStore(bool, &self.closing, true, .release);
    }

    fn isReleased(self: *ExecutorCallBarrier) bool {
        return @atomicLoad(bool, &self.released, .acquire);
    }
};

/// Deterministic test synchronization for concurrent shutdown callers. The
/// counter is advanced only after a caller has found the stable registry slot.
pub const ShutdownCallBarrier = struct {
    callers: u32 = 0,
    reclaimed: bool = false,

    pub fn markCaller(self: *ShutdownCallBarrier) void {
        _ = @atomicRmw(u32, &self.callers, .Add, 1, .release);
    }

    pub fn waitForCallers(self: *ShutdownCallBarrier, expected: u32, io: std.Io) !void {
        const deadline = std.Io.Clock.Timestamp.fromNow(io, .{
            .raw = .fromSeconds(1),
            .clock = .awake,
        });
        const pause = std.Io.Clock.Duration{
            .raw = .fromMilliseconds(1),
            .clock = .awake,
        };
        while (@atomicLoad(u32, &self.callers, .acquire) < expected) {
            if (std.Io.Clock.Timestamp.now(io, .awake).compare(.gte, deadline)) {
                return error.TestTimeout;
            }
            try pause.sleep(io);
        }
    }

    pub fn hasReclaimed(self: *ShutdownCallBarrier) bool {
        return @atomicLoad(bool, &self.reclaimed, .acquire);
    }

    pub fn markReclaimed(self: *ShutdownCallBarrier) void {
        @atomicStore(bool, &self.reclaimed, true, .release);
    }
};

pub const Faults = struct {
    canonicalization: bool = false,
    identity_inspection: bool = false,
    registration: bool = false,
    lease_acquire: bool = false,
    engine_open: bool = false,
    transaction_begin: bool = false,
    callback: bool = false,
    rollback: bool = false,
    commit: bool = false,
    checkpoint: bool = false,
    directory_open: bool = false,
    directory_sync: bool = false,
    directory_close: bool = false,
    dirty_discard: bool = false,
    reopen: bool = false,
    unsupported_directory_sync: bool = false,
    shutdown: bool = false,
    executor_registration: bool = false,
    executor_call_barrier: ?*ExecutorCallBarrier = null,
    shutdown_call_barrier: ?*ShutdownCallBarrier = null,
};

const ExecutorKind = enum(u8) {
    normal,
    startup,
};

const ExecutorSlot = struct {
    next: ?*ExecutorSlot = null,
    id: u128 = 0,
    adapter: *shovelerdb.Adapter,
    allocator: std.mem.Allocator,
    kind: ExecutorKind,
    io: std.Io = undefined,
    active: usize = 0,
    closing: bool = false,
    barrier: ?*ExecutorCallBarrier = null,
};

var executor_registry_mutex: std.atomic.Mutex = .unlocked;
var executor_registry_head: ?*ExecutorSlot = null;

pub const ScopedExecutor = struct {
    id: u128,
    kind: ExecutorKind,

    pub fn close(self: *ScopedExecutor) void {
        if (self.id == 0) return;
        closeExecutor(self.id);
        self.id = 0;
    }
};

pub fn scopedExecutor(
    io: std.Io,
    adapter: *shovelerdb.Adapter,
    faults: Faults,
) StoreError!ScopedExecutor {
    if (faults.executor_registration) return StoreError.OutOfMemory;
    return registerExecutor(io, adapter, .normal, faults.executor_call_barrier);
}

pub fn scopedStartupExecutor(
    io: std.Io,
    adapter: *shovelerdb.Adapter,
    faults: Faults,
) StoreError!ScopedExecutor {
    if (faults.executor_registration) return StoreError.OutOfMemory;
    return registerExecutor(io, adapter, .startup, faults.executor_call_barrier);
}

pub fn executor(scope: *const ScopedExecutor) Executor {
    std.debug.assert(scope.kind == .normal and scope.id != 0);
    return @enumFromInt(scope.id);
}

pub fn startupExecutor(scope: *const ScopedExecutor) StartupExecutor {
    std.debug.assert(scope.kind == .startup and scope.id != 0);
    return @enumFromInt(scope.id);
}

pub fn begin(adapter: *shovelerdb.Adapter, faults: Faults) StoreError!void {
    if (faults.transaction_begin) {
        persistence_coverage.hit(.transaction_begin_failure);
        return StoreError.TransactionBeginFailed;
    }
    adapter.begin() catch {
        persistence_coverage.hit(.transaction_begin_failure);
        return StoreError.TransactionBeginFailed;
    };
}

pub fn callbackFailed() void {
    persistence_coverage.hit(.callback_failure);
}

pub fn rollback(adapter: *shovelerdb.Adapter, faults: Faults) StoreError!void {
    if (faults.rollback) {
        persistence_coverage.hit(.rollback_failure);
        return StoreError.RollbackFailed;
    }
    adapter.rollback() catch {
        persistence_coverage.hit(.rollback_failure);
        return StoreError.RollbackFailed;
    };
}

pub fn commit(adapter: *shovelerdb.Adapter, faults: Faults) StoreError!void {
    if (faults.commit) {
        persistence_coverage.hit(.commit_failure);
        return StoreError.CommitFailed;
    }
    adapter.commit() catch {
        persistence_coverage.hit(.commit_failure);
        return StoreError.CommitFailed;
    };
}

pub fn checkpoint(adapter: *shovelerdb.Adapter, faults: Faults) StoreError!void {
    if (faults.checkpoint) {
        persistence_coverage.hit(.checkpoint_failure);
        return StoreError.CheckpointFailed;
    }
    adapter.checkpoint() catch {
        persistence_coverage.hit(.checkpoint_failure);
        return StoreError.CheckpointFailed;
    };
}

fn neutralResult(result: shovelerdb.OwnedResult) StatementResult {
    return switch (result) {
        .empty => .empty,
        .mutation_count => |count| .{ .mutation_count = count },
        .rows => |rows| .{ .row_count = rows.rows.len },
    };
}

fn ownedRow(self: *const RowView) *const shovelerdb.OwnedRow {
    return @ptrCast(@alignCast(self));
}

fn rowView(row: *const shovelerdb.OwnedRow) *const RowView {
    return @ptrCast(row);
}

fn neutralValue(value: shovelerdb.OwnedValue) RowValue {
    return switch (value) {
        .null_value => .null_value,
        .integer => |integer| .{ .integer = integer },
        .float => |float| .{ .float = float },
        .boolean => |boolean| .{ .boolean = boolean },
        .text => |text| .{ .text = text },
        .blob => |blob| .{ .blob = blob },
        .vector_f32 => |vector| .{ .vector_f32 = vector },
    };
}

fn executeReviewed(adapter: *shovelerdb.Adapter, comptime sql: [:0]const u8) StoreError!StatementResult {
    var result = adapter.execute(adapter.allocator, sql) catch |err| return statementError(err);
    defer result.deinit(adapter.allocator);
    return neutralResult(result);
}

fn executeOneText(
    adapter: *shovelerdb.Adapter,
    comptime prefix: []const u8,
    text: []const u8,
    comptime suffix: []const u8,
) StoreError!StatementResult {
    var result = adapter.executeText(adapter.allocator, prefix, text, suffix) catch |err| return statementError(err);
    defer result.deinit(adapter.allocator);
    return neutralResult(result);
}

fn executeBoundValues(
    adapter: *shovelerdb.Adapter,
    comptime fragments: []const []const u8,
    values: []const []const u8,
) StoreError!StatementResult {
    var result = adapter.executeBound(adapter.allocator, fragments, values) catch |err| return statementError(err);
    defer result.deinit(adapter.allocator);
    return neutralResult(result);
}

fn queryReviewed(
    adapter: *shovelerdb.Adapter,
    comptime sql: [:0]const u8,
    visitor: RowVisitor,
) anyerror!usize {
    var result = adapter.execute(adapter.allocator, sql) catch |err| return statementError(err);
    defer result.deinit(adapter.allocator);
    return visitRows(&result, visitor);
}

fn queryBoundValues(
    adapter: *shovelerdb.Adapter,
    comptime fragments: []const []const u8,
    values: []const []const u8,
    visitor: RowVisitor,
) anyerror!usize {
    var result = adapter.executeBound(adapter.allocator, fragments, values) catch |err| return statementError(err);
    defer result.deinit(adapter.allocator);
    return visitRows(&result, visitor);
}

fn visitRows(result: *const shovelerdb.OwnedResult, visitor: RowVisitor) anyerror!usize {
    return switch (result.*) {
        .rows => |rows| rows: {
            for (rows.rows) |*row| try visitor.visit(visitor.context, rowView(row));
            break :rows rows.rows.len;
        },
        else => StoreError.StatementRowsRequired,
    };
}

fn statementError(err: anyerror) StoreError {
    return switch (shovelerdb.category(err)) {
        .invalid_argument => StoreError.StatementInvalid,
        .closed => StoreError.StoreClosed,
        .allocation => StoreError.OutOfMemory,
        .parse => StoreError.StatementParseFailed,
        .object => StoreError.StatementObjectFailed,
        .transaction => StoreError.StatementTransactionFailed,
        .type_mismatch, .vector => StoreError.StatementTypeMismatch,
        .persistence => StoreError.StatementPersistenceFailed,
        .io => StoreError.StatementIoFailed,
        .unsupported => StoreError.StatementUnsupported,
        .embedded_nul => StoreError.StatementEmbeddedNul,
        .binding_arity_mismatch => StoreError.StatementBindingArityMismatch,
        .internal, .abi_mismatch => StoreError.StatementInternal,
    };
}

const ExecutorAdmission = struct {
    slot: *ExecutorSlot,
    adapter: *shovelerdb.Adapter,
    io: std.Io,
    barrier: ?*ExecutorCallBarrier,

    fn release(self: ExecutorAdmission) void {
        lockExecutorRegistry();
        defer executor_registry_mutex.unlock();
        std.debug.assert(self.slot.active > 0);
        self.slot.active -= 1;
    }

    fn pauseAfterAdmission(self: ExecutorAdmission) void {
        const barrier = self.barrier orelse return;
        barrier.markAdmitted();
        const deadline = std.Io.Clock.Timestamp.fromNow(self.io, .{
            .raw = .fromSeconds(5),
            .clock = .awake,
        });
        const pause = std.Io.Clock.Duration{
            .raw = .fromMilliseconds(1),
            .clock = .awake,
        };
        while (!barrier.isReleased()) {
            if (std.Io.Clock.Timestamp.now(self.io, .awake).compare(.gte, deadline)) return;
            pause.sleep(self.io) catch return;
        }
    }
};

fn registerExecutor(
    io: std.Io,
    adapter: *shovelerdb.Adapter,
    kind: ExecutorKind,
    barrier: ?*ExecutorCallBarrier,
) StoreError!ScopedExecutor {
    for (0..32) |_| {
        var nonce_bytes: [16]u8 = undefined;
        std.Io.randomSecure(io, &nonce_bytes) catch return StoreError.CapabilityGenerationFailed;
        var id: u128 = @bitCast(nonce_bytes);
        id |= @as(u128, 1) << 127;

        lockExecutorRegistry();
        var collision = false;
        var current = executor_registry_head;
        while (current) |slot| : (current = slot.next) {
            if (slot.id == id) collision = true;
        }
        if (collision) {
            executor_registry_mutex.unlock();
            continue;
        }
        const slot = adapter.allocator.create(ExecutorSlot) catch {
            executor_registry_mutex.unlock();
            return StoreError.OutOfMemory;
        };
        slot.* = .{
            .next = executor_registry_head,
            .id = id,
            .adapter = adapter,
            .allocator = adapter.allocator,
            .kind = kind,
            .io = io,
            .barrier = barrier,
        };
        executor_registry_head = slot;
        executor_registry_mutex.unlock();
        return .{ .id = id, .kind = kind };
    }
    return StoreError.CapabilityGenerationFailed;
}

fn admitExecutor(id: u128, expected_kind: ExecutorKind) StoreError!ExecutorAdmission {
    if (id == 0) return StoreError.CapabilityDenied;
    lockExecutorRegistry();
    defer executor_registry_mutex.unlock();
    var current = executor_registry_head;
    while (current) |slot| : (current = slot.next) {
        if (slot.id != id) continue;
        if (slot.closing or slot.kind != expected_kind) return StoreError.CapabilityDenied;
        slot.active += 1;
        return .{
            .slot = slot,
            .adapter = slot.adapter,
            .io = slot.io,
            .barrier = slot.barrier,
        };
    }
    return StoreError.CapabilityDenied;
}

fn closeExecutor(id: u128) void {
    lockExecutorRegistry();
    var target: ?*ExecutorSlot = null;
    var current = executor_registry_head;
    while (current) |slot| : (current = slot.next) {
        if (slot.id != id) continue;
        slot.closing = true;
        target = slot;
        break;
    }
    const slot = target orelse {
        executor_registry_mutex.unlock();
        return;
    };
    const barrier = slot.barrier;
    executor_registry_mutex.unlock();
    if (barrier) |value| value.markClosing();

    const pause = std.Io.Clock.Duration{
        .raw = .fromMilliseconds(1),
        .clock = .awake,
    };
    while (true) {
        lockExecutorRegistry();
        if (slot.active == 0) {
            const allocator = slot.allocator;
            removeExecutorSlotLocked(slot);
            executor_registry_mutex.unlock();
            allocator.destroy(slot);
            return;
        }
        const io = slot.io;
        executor_registry_mutex.unlock();
        pause.sleep(io) catch {};
    }
}

fn removeExecutorSlotLocked(target: *ExecutorSlot) void {
    var previous: ?*ExecutorSlot = null;
    var current = executor_registry_head;
    while (current) |slot| : (current = slot.next) {
        if (slot == target) {
            if (previous) |value| {
                value.next = slot.next;
            } else {
                executor_registry_head = slot.next;
            }
            return;
        }
        previous = slot;
    }
    unreachable;
}

fn lockExecutorRegistry() void {
    while (!executor_registry_mutex.tryLock()) std.atomic.spinLoopHint();
}
