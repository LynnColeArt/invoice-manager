const builtin = @import("builtin");
const diagnostics = @import("diagnostics.zig");
const durability = @import("durability.zig");
const store = @import("store.zig");

pub const State = diagnostics.State;
pub const Diagnostic = diagnostics.Diagnostic;
pub const DiagnosticCategory = diagnostics.DiagnosticCategory;
pub const StoreError = diagnostics.StoreError;
pub const DurableReceipt = durability.DurableReceipt;
pub const DurabilityEvent = durability.DurabilityEvent;
pub const StatementResult = durability.StatementResult;
pub const Executor = durability.Executor;
pub const WriteOperation = durability.WriteOperation;
pub const Store = store.Store;

pub const testing = if (builtin.is_test) struct {
    pub const Faults = durability.Faults;

    pub fn openWithFaults(
        allocator: @import("std").mem.Allocator,
        io: @import("std").Io,
        path: []const u8,
        faults: Faults,
    ) StoreError!Store {
        return store.openWithFaults(allocator, io, path, faults);
    }

    pub fn setFaults(durable_store: *Store, faults: Faults) void {
        store.setFaults(durable_store, faults);
    }

    pub fn checkpointCount(durable_store: *const Store) usize {
        return store.checkpointCount(durable_store);
    }

    pub fn discardCount(durable_store: *const Store) usize {
        return store.discardCount(durable_store);
    }

    pub fn reopenCount(durable_store: *const Store) usize {
        return store.reopenCount(durable_store);
    }

    pub fn openDirectoryCount(durable_store: *const Store) usize {
        return store.openDirectoryCount(durable_store);
    }

    pub fn receiptIssued(durable_store: *const Store) bool {
        return store.receiptIssued(durable_store);
    }

    pub fn events(durable_store: *const Store) []const DurabilityEvent {
        return store.events(durable_store);
    }

    pub fn rowCount(durable_store: *Store, comptime sql: [:0]const u8) StoreError!usize {
        return store.rowCount(durable_store, sql);
    }
} else struct {};
