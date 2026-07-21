const std = @import("std");

pub const State = enum {
    closed,
    ready,
    mutating,
    committed_pending_checkpoint,
    checkpointed_pending_directory_sync,
    directory_synchronized,
    uncertain,
    quarantined,
};

pub const DiagnosticCategory = enum {
    canonicalization_failure,
    lease_acquire_failure,
    lease_conflict,
    engine_open_failure,
    transaction_begin_failure,
    callback_failure,
    rollback_failure,
    commit_failure,
    checkpoint_failure,
    directory_open_failure,
    directory_sync_failure,
    directory_close_failure,
    uncertainty,
    quarantine,
    dirty_discard_failure,
    reopen_failure,
    unsupported_directory_sync,
    shutdown_failure,
};

pub const Cause = enum {
    invalid_path,
    resource_busy,
    allocation,
    transaction,
    persistence,
    io,
    unsupported,
    injected_fault,
    internal,
};

/// This deliberately contains no free-form engine or application text.
pub const Diagnostic = struct {
    category: DiagnosticCategory,
    store_id: u64,
    state: State,
    cause: Cause,
    sensitive_detail: ?[]const u8 = null,
};

pub const StoreError = error{
    OutOfMemory,
    CapabilityGenerationFailed,
    CanonicalizationFailed,
    LeaseAcquireFailed,
    LeaseConflict,
    EngineOpenFailed,
    StoreClosed,
    StoreQuarantined,
    TransactionBeginFailed,
    CallbackFailed,
    RollbackFailed,
    CommitFailed,
    CheckpointFailed,
    DirectoryOpenFailed,
    DirectorySyncFailed,
    DirectoryCloseFailed,
    UnsupportedDirectorySync,
    StartupWriteFailed,
    DirtyDiscardFailed,
    ReopenFailed,
    ShutdownFailed,
    QueryFailed,
    StatementInvalid,
    StatementParseFailed,
    StatementObjectFailed,
    StatementTransactionFailed,
    StatementTypeMismatch,
    StatementPersistenceFailed,
    StatementIoFailed,
    StatementUnsupported,
    StatementEmbeddedNul,
    StatementBindingArityMismatch,
    StatementInternal,
    StatementRowsRequired,
    RowIndexOutOfBounds,
    DurabilityCompletionUnavailable,
    CapabilityDenied,
};

pub fn stableStoreId(canonical_path: []const u8) u64 {
    return std.hash.Wyhash.hash(0x5750_3036, canonical_path);
}
