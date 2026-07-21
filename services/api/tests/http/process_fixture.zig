const std = @import("std");
const http_test_config = @import("http_test_config");

pub const maximum_response_bytes = 64 * 1024;
const ready_timeout = std.Io.Clock.Duration{ .raw = .fromSeconds(5), .clock = .awake };
const request_timeout = std.Io.Clock.Duration{ .raw = .fromSeconds(3), .clock = .awake };

pub const Service = struct {
    allocator: std.mem.Allocator,
    tmp: std.testing.TmpDir,
    database_path: []u8,
    address: std.Io.net.IpAddress,
    child: std.process.Child,

    pub fn start(allocator: std.mem.Allocator, io: std.Io) !Service {
        var tmp = std.testing.tmpDir(.{});
        errdefer tmp.cleanup();
        const database_path = try std.fmt.allocPrint(
            allocator,
            ".zig-cache/tmp/{s}/wp08-black-box.shovel",
            .{tmp.sub_path},
        );
        errdefer allocator.free(database_path);
        var environment = try std.process.Environ.createMap(std.testing.environ, allocator);
        defer environment.deinit();
        try environment.put("INVOICE_API_BIND", "127.0.0.1");
        try environment.put("INVOICE_API_PORT", "0");
        try environment.put("INVOICE_DATABASE_PATH", database_path);
        var child = try std.process.spawn(io, .{
            .argv = &.{http_test_config.api_executable_path},
            .environ_map = &environment,
            .stdin = .ignore,
            .stdout = .ignore,
            .stderr = .pipe,
        });
        errdefer child.kill(io);
        const ready_port = try waitForReady(io, child.stderr.?);
        const address = try std.Io.net.IpAddress.parse("127.0.0.1", ready_port);
        return .{
            .allocator = allocator,
            .tmp = tmp,
            .database_path = database_path,
            .address = address,
            .child = child,
        };
    }

    pub fn stop(self: *Service, io: std.Io) void {
        // Child.kill is idempotent and synchronously reaps before returning.
        self.child.kill(io);
        self.release();
    }

    pub fn stopGracefully(self: *Service, io: std.Io) !std.process.Child.Term {
        try std.posix.kill(self.child.id.?, .TERM);
        var select_buffer: [2]WaitSelect = undefined;
        var select = std.Io.Select(WaitSelect).init(io, &select_buffer);
        select.async(.child, waitChild, .{ &self.child, io });
        select.async(.timeout, waitReadyTimeout, .{io});
        const selected = select.await() catch |err| switch (err) {
            error.Canceled => {
                select.cancelDiscard();
                return error.Canceled;
            },
        };
        select.cancelDiscard();
        const term = switch (selected) {
            .timeout => return error.ShutdownTimeout,
            .child => |result| switch (result) {
                .term => |term| term,
                .failed => return error.ChildWaitFailed,
            },
        };
        self.release();
        return term;
    }

    fn release(self: *Service) void {
        self.allocator.free(self.database_path);
        self.tmp.cleanup();
        self.* = undefined;
    }

    pub fn request(self: *const Service, raw_request: []const u8) ![]u8 {
        var select_buffer: [2]RequestSelect = undefined;
        var select = std.Io.Select(RequestSelect).init(std.testing.io, &select_buffer);
        select.async(.request, roundTrip, .{ self.allocator, self.address, raw_request });
        select.async(.timeout, waitRequestTimeout, .{});
        const selected = select.await() catch |err| switch (err) {
            error.Canceled => {
                drainRequestSelect(&select, self.allocator);
                return error.Canceled;
            },
        };
        drainRequestSelect(&select, self.allocator);
        return switch (selected) {
            .timeout => error.RequestTimeout,
            .request => |result| switch (result) {
                .bytes => |bytes| bytes,
                .failed => error.RequestFailed,
            },
        };
    }

    pub fn disconnect(self: *const Service, partial_request: []const u8) !void {
        const stream = try self.address.connect(std.testing.io, .{ .mode = .stream });
        defer stream.close(std.testing.io);
        var write_buffer: [256]u8 = undefined;
        var writer = stream.writer(std.testing.io, &write_buffer);
        try writer.interface.writeAll(partial_request);
        try writer.interface.flush();
    }

    pub fn expectPartialClosedByHeaderDeadline(self: *const Service, partial_request: []const u8) !void {
        const stream = try self.address.connect(std.testing.io, .{ .mode = .stream });
        defer stream.close(std.testing.io);
        var write_buffer: [256]u8 = undefined;
        var writer = stream.writer(std.testing.io, &write_buffer);
        try writer.interface.writeAll(partial_request);
        try writer.interface.flush();
        var read_buffer: [32]u8 = undefined;
        var reader = stream.reader(std.testing.io, &read_buffer);
        var select_buffer: [2]CloseSelect = undefined;
        var select = std.Io.Select(CloseSelect).init(std.testing.io, &select_buffer);
        select.async(.peer, waitForPeerClosure, .{&reader});
        select.async(.timeout, waitRequestTimeout, .{});
        const selected = select.await() catch |err| switch (err) {
            error.Canceled => {
                select.cancelDiscard();
                return error.Canceled;
            },
        };
        select.cancelDiscard();
        switch (selected) {
            .timeout => return error.HeaderDeadlineNotEnforced,
            .peer => |result| switch (result) {
                .closed => return,
                .data => return error.UnexpectedPartialResponse,
                .failed => return error.PartialReadFailed,
            },
        }
    }
};

const WaitResult = union(enum) { term: std.process.Child.Term, failed };
const WaitSelect = union(enum) { child: WaitResult, timeout: void };

fn waitChild(child: *std.process.Child, io: std.Io) WaitResult {
    const term = child.wait(io) catch return .failed;
    return .{ .term = term };
}

const CloseResult = enum { closed, data, failed };
const CloseSelect = union(enum) { peer: CloseResult, timeout: void };

fn waitForPeerClosure(reader: *std.Io.net.Stream.Reader) CloseResult {
    _ = reader.interface.takeByte() catch |err| switch (err) {
        error.EndOfStream => return .closed,
        error.ReadFailed => {
            const read_err = reader.err orelse return .failed;
            return if (read_err == error.ConnectionResetByPeer) .closed else .failed;
        },
    };
    return .data;
}

fn drainRequestSelect(
    select: *std.Io.Select(RequestSelect),
    allocator: std.mem.Allocator,
) void {
    while (select.cancel()) |remaining| switch (remaining) {
        .timeout => {},
        .request => |result| switch (result) {
            .bytes => |bytes| allocator.free(bytes),
            .failed => {},
        },
    };
}

pub fn unusedLoopbackAddress(io: std.Io) !std.Io.net.IpAddress {
    var candidate = try std.Io.net.IpAddress.parse("127.0.0.1", 0);
    var reservation = try candidate.listen(io, .{ .reuse_address = false });
    const selected = reservation.socket.address;
    reservation.deinit(io);
    return selected;
}

const ReadyResult = union(enum) { ready: u16, unexpected, closed, canceled };
const ReadySelect = union(enum) { line: ReadyResult, timeout: void };

fn waitForReady(io: std.Io, stderr_file: std.Io.File) !u16 {
    var read_buffer: [512]u8 = undefined;
    var reader = stderr_file.readerStreaming(io, &read_buffer);
    var select_buffer: [2]ReadySelect = undefined;
    var select = std.Io.Select(ReadySelect).init(io, &select_buffer);
    select.async(.line, readReadyLine, .{&reader.interface});
    select.async(.timeout, waitReadyTimeout, .{io});
    const selected = select.await() catch |err| switch (err) {
        error.Canceled => return error.Canceled,
    };
    select.cancelDiscard();
    switch (selected) {
        .timeout => return error.ReadyTimeout,
        .line => |result| switch (result) {
            .ready => |port| return port,
            .unexpected => return error.UnexpectedStartupDiagnostic,
            .closed => return error.ProcessExitedBeforeReady,
            .canceled => return error.Canceled,
        },
    }
}

fn readReadyLine(reader: *std.Io.Reader) ReadyResult {
    const line = reader.takeDelimiterInclusive('\n') catch |err| switch (err) {
        error.EndOfStream => return .closed,
        error.ReadFailed => return .canceled,
        error.StreamTooLong => return .unexpected,
    };
    const prefix = "[api:ready] listening port=";
    if (!std.mem.startsWith(u8, line, prefix) or line.len <= prefix.len + 1 or line[line.len - 1] != '\n') {
        return .unexpected;
    }
    const port = std.fmt.parseInt(u16, line[prefix.len .. line.len - 1], 10) catch return .unexpected;
    if (port == 0) return .unexpected;
    return .{ .ready = port };
}

fn waitReadyTimeout(io: std.Io) void {
    ready_timeout.sleep(io) catch {};
}

const RequestResult = union(enum) { bytes: []u8, failed };
const RequestSelect = union(enum) { request: RequestResult, timeout: void };

fn roundTrip(
    allocator: std.mem.Allocator,
    address: std.Io.net.IpAddress,
    raw_request: []const u8,
) RequestResult {
    const stream = address.connect(std.testing.io, .{ .mode = .stream }) catch return .failed;
    defer stream.close(std.testing.io);
    var write_buffer: [1024]u8 = undefined;
    var writer = stream.writer(std.testing.io, &write_buffer);
    writer.interface.writeAll(raw_request) catch return .failed;
    writer.interface.flush() catch return .failed;
    stream.shutdown(std.testing.io, .send) catch return .failed;
    var read_buffer: [4096]u8 = undefined;
    var reader = stream.reader(std.testing.io, &read_buffer);
    const bytes = reader.interface.allocRemaining(
        allocator,
        .limited(maximum_response_bytes),
    ) catch return .failed;
    return .{ .bytes = bytes };
}

fn waitRequestTimeout() void {
    request_timeout.sleep(std.testing.io) catch {};
}
