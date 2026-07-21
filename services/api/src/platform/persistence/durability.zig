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

/// A capability-limited statement executor. Its context is opaque and the
/// ShovelerDB adapter type is not part of the public persistence contract.
pub const Executor = struct {
    _context: *anyopaque,

    pub fn execute(self: *Executor, comptime sql: [:0]const u8) StoreError!StatementResult {
        const adapter: *shovelerdb.Adapter = @ptrCast(@alignCast(self._context));
        var result = adapter.execute(adapter.allocator, sql) catch return StoreError.CallbackFailed;
        defer result.deinit(adapter.allocator);
        return neutralResult(result);
    }

    pub fn executeText(
        self: *Executor,
        comptime prefix: []const u8,
        text: []const u8,
        comptime suffix: []const u8,
    ) StoreError!StatementResult {
        const adapter: *shovelerdb.Adapter = @ptrCast(@alignCast(self._context));
        var result = adapter.executeText(adapter.allocator, prefix, text, suffix) catch return StoreError.CallbackFailed;
        defer result.deinit(adapter.allocator);
        return neutralResult(result);
    }
};

/// A write callback and its opaque application context. This keeps the store
/// implementation monomorphic while exposing only the capability-limited
/// executor at the callback boundary.
pub const WriteOperation = struct {
    context: *anyopaque,
    run: *const fn (*anyopaque, *Executor) anyerror!void,
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
};

pub const Faults = struct {
    canonicalization: bool = false,
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
};

pub fn executor(adapter: *shovelerdb.Adapter) Executor {
    return .{ ._context = adapter };
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
