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
        const address = try unusedLoopbackAddress(io);
        var port_buffer: [5]u8 = undefined;
        const port = try std.fmt.bufPrint(&port_buffer, "{d}", .{address.getPort()});
        var environment = try std.process.Environ.createMap(std.testing.environ, allocator);
        defer environment.deinit();
        try environment.put("INVOICE_API_BIND", "127.0.0.1");
        try environment.put("INVOICE_API_PORT", port);
        try environment.put("INVOICE_DATABASE_PATH", database_path);
        var child = try std.process.spawn(io, .{
            .argv = &.{http_test_config.api_executable_path},
            .environ_map = &environment,
            .stdin = .ignore,
            .stdout = .ignore,
            .stderr = .pipe,
        });
        errdefer child.kill(io);
        try waitForReady(io, child.stderr.?);
        return .{
            .allocator = allocator,
            .tmp = tmp,
            .database_path = database_path,
            .address = address,
            .child = child,
        };
    }

    pub fn stop(self: *Service, io: std.Io) void {
        self.child.kill(io);
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
            error.Canceled => return error.Canceled,
        };
        select.cancelDiscard();
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
};

pub fn unusedLoopbackAddress(io: std.Io) !std.Io.net.IpAddress {
    var candidate = try std.Io.net.IpAddress.parse("127.0.0.1", 0);
    var reservation = try candidate.listen(io, .{ .reuse_address = false });
    const selected = reservation.socket.address;
    reservation.deinit(io);
    return selected;
}

const ReadyResult = enum { ready, unexpected, closed, canceled };
const ReadySelect = union(enum) { line: ReadyResult, timeout: void };

fn waitForReady(io: std.Io, stderr_file: std.Io.File) !void {
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
            .ready => return,
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
    return if (std.mem.eql(u8, line, "[api:ready] listening\n")) .ready else .unexpected;
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
