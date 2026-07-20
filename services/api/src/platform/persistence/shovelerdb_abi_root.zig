//! Invoice Manager's build-only root for the vendored ShovelerDB C ABI.
//! The application imports only `shovelerdb.h`; this root exists solely to
//! force the upstream exported ABI declarations into one linkable library.

comptime {
    _ = @import("shovelerdb_source").abi.c_api;
}
