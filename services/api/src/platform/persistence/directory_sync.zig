const std = @import("std");
const builtin = @import("builtin");
const persistence_coverage = @import("persistence_coverage_probe");
const durability = @import("durability.zig");

pub const Stats = struct {
    live_descriptors: usize = 0,
};

pub fn syncParent(
    io: std.Io,
    canonical_database_path: []const u8,
    faults: durability.Faults,
    stats: *Stats,
) durability.StoreError!void {
    if (faults.unsupported_directory_sync or builtin.os.tag != .linux) {
        persistence_coverage.hit(.unsupported_directory_sync);
        return durability.StoreError.UnsupportedDirectorySync;
    }

    const parent = std.fs.path.dirname(canonical_database_path) orelse {
        persistence_coverage.hit(.directory_open_failure);
        return durability.StoreError.DirectoryOpenFailed;
    };
    if (faults.directory_open) {
        persistence_coverage.hit(.directory_open_failure);
        return durability.StoreError.DirectoryOpenFailed;
    }

    const fd = std.posix.openat(
        std.posix.AT.FDCWD,
        parent,
        .{ .ACCMODE = .RDONLY, .DIRECTORY = true, .CLOEXEC = true },
        0,
    ) catch {
        persistence_coverage.hit(.directory_open_failure);
        return durability.StoreError.DirectoryOpenFailed;
    };
    var directory_file = std.Io.File{ .handle = fd, .flags = .{ .nonblocking = false } };
    stats.live_descriptors += 1;

    if (faults.directory_sync) {
        directory_file.close(io);
        stats.live_descriptors -= 1;
        persistence_coverage.hit(.directory_sync_failure);
        return durability.StoreError.DirectorySyncFailed;
    }
    directory_file.sync(io) catch {
        directory_file.close(io);
        stats.live_descriptors -= 1;
        persistence_coverage.hit(.directory_sync_failure);
        return durability.StoreError.DirectorySyncFailed;
    };

    directory_file.close(io);
    stats.live_descriptors -= 1;
    if (faults.directory_close) {
        persistence_coverage.hit(.directory_close_failure);
        return durability.StoreError.DirectoryCloseFailed;
    }
}
