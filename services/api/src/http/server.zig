const std = @import("std");
const envelope = @import("envelope.zig");
const error_mapping = @import("error_mapping.zig");
const health = @import("health.zig");

pub const maximum_header_bytes = 16 * 1024;
pub const maximum_request_line_bytes = 2 * 1024;
pub const maximum_body_bytes = 16 * 1024;
pub const content_type = "application/json; charset=utf-8";

const ReadyProof = struct {};
const ready_proof = ReadyProof{};

/// A listener capability whose proof pointer can only be minted by the
/// dependency-readiness admission function below. HTTP code never imports
/// persistence or migration implementation details.
pub const ReadyContext = struct {
    proof: *const ReadyProof,

    fn valid(self: ReadyContext) bool {
        return self.proof == &ready_proof;
    }
};

/// Composition-root admission point. Callers must pass the typed public
/// readiness results; a false dependency result cannot produce a capability.
pub fn compositionRootReadyContext(
    store_ready: bool,
    migrations_ready: bool,
) error{NotReady}!ReadyContext {
    if (!store_ready or !migrations_ready) return error.NotReady;
    return .{ .proof = &ready_proof };
}

pub const RouteMetadata = struct {
    operation_id: []const u8,
    method: []const u8,
    path: []const u8,
    access: []const u8,
};

pub const Request = struct {
    method: []const u8,
    path: []const u8,
};

pub const DispatchContext = struct {
    ready: bool,
    handler_calls: *usize,
    io: std.Io,
};

pub const Response = struct {
    allocator: std.mem.Allocator,
    status: u16,
    reason: []const u8,
    body: []u8,

    pub fn deinit(self: *Response) void {
        self.allocator.free(self.body);
        self.* = undefined;
    }
};

pub fn requestId(io: std.Io, output: *[36]u8) ![]const u8 {
    const now = std.Io.Clock.real.now(io).toMilliseconds();
    if (now < 0 or now > 0xffffffffffff) return error.ClockOutOfRange;

    var bytes: [16]u8 = undefined;
    const milliseconds: u64 = @intCast(now);
    bytes[0] = @truncate(milliseconds >> 40);
    bytes[1] = @truncate(milliseconds >> 32);
    bytes[2] = @truncate(milliseconds >> 24);
    bytes[3] = @truncate(milliseconds >> 16);
    bytes[4] = @truncate(milliseconds >> 8);
    bytes[5] = @truncate(milliseconds);
    io.random(bytes[6..]);
    bytes[6] = (bytes[6] & 0x0f) | 0x70;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    var output_index: usize = 0;
    for (bytes, 0..) |byte, byte_index| {
        if (byte_index == 4 or byte_index == 6 or byte_index == 8 or byte_index == 10) {
            output[output_index] = '-';
            output_index += 1;
        }
        output[output_index] = hexDigit(byte >> 4);
        output[output_index + 1] = hexDigit(byte & 0x0f);
        output_index += 2;
    }
    const value: []const u8 = output;
    _ = @import("shared").RequestId.parse(value) catch return error.InvalidGeneratedRequestId;
    return value;
}

fn hexDigit(nibble: u8) u8 {
    return if (nibble < 10) '0' + nibble else 'a' + nibble - 10;
}

pub fn dispatch(
    allocator: std.mem.Allocator,
    route: ?RouteMetadata,
    request: Request,
    context: *DispatchContext,
) !Response {
    var request_id_storage: [36]u8 = undefined;
    const generated_request_id = try requestId(context.io, &request_id_storage);

    const metadata = route orelse return failureResponse(allocator, generated_request_id, .not_found);
    if (!std.mem.eql(u8, request.path, metadata.path)) {
        return failureResponse(allocator, generated_request_id, .not_found);
    }
    // Route inventory methods are canonical lowercase values. HTTP parsing
    // translates the wire enum once; comparison against inventory is exact.
    if (!std.mem.eql(u8, request.method, metadata.method)) {
        return failureResponse(allocator, generated_request_id, .method_not_allowed);
    }
    if (!context.ready) return failureResponse(allocator, generated_request_id, .not_ready);
    if (!std.mem.eql(u8, metadata.operation_id, "P0Health")) {
        return failureResponse(allocator, generated_request_id, .not_found);
    }

    context.handler_calls.* += 1;
    return .{
        .allocator = allocator,
        .status = 200,
        .reason = "OK",
        .body = try health.respond(allocator, generated_request_id),
    };
}

fn failureResponse(
    allocator: std.mem.Allocator,
    generated_request_id: []const u8,
    kind: error_mapping.Kind,
) !Response {
    const public_error = error_mapping.map(kind);
    return .{
        .allocator = allocator,
        .status = public_error.status,
        .reason = public_error.reason,
        .body = try envelope.failure(
            allocator,
            generated_request_id,
            public_error.code,
            public_error.message,
            &.{},
        ),
    };
}

pub const Listener = struct {
    server: std.Io.net.Server,

    pub fn listen(io: std.Io, bind_address_value: std.Io.net.IpAddress, ready: ReadyContext) !Listener {
        if (!ready.valid()) return error.NotReady;
        var bind_address = bind_address_value;
        return .{ .server = try bind_address.listen(io, .{ .reuse_address = true }) };
    }

    pub fn address(self: *const Listener) std.Io.net.IpAddress {
        return self.server.socket.address;
    }

    pub fn deinit(self: *Listener, io: std.Io) void {
        self.server.deinit(io);
    }

    /// Serves one connection. `accept`, header reads, response writes, and
    /// shutdown preserve the underlying `error.Canceled` signal.
    pub fn serveOne(
        self: *Listener,
        allocator: std.mem.Allocator,
        io: std.Io,
        route: RouteMetadata,
        context: *DispatchContext,
    ) !void {
        const stream = try self.server.accept(io);
        defer stream.close(io);

        var read_buffer: [maximum_header_bytes]u8 = undefined;
        var socket_reader = stream.reader(io, &read_buffer);
        var write_buffer: [4096]u8 = undefined;
        var socket_writer = stream.writer(io, &write_buffer);
        var http_server = std.http.Server.init(&socket_reader.interface, &socket_writer.interface);
        var request = http_server.receiveHead() catch {
            if (socket_reader.err) |read_error| if (read_error == error.Canceled) return error.Canceled;
            try writeMappedRaw(stream, io, allocator, .malformed_request, context);
            return;
        };

        const first_line_end = std.mem.indexOf(u8, request.head_buffer, "\r\n") orelse {
            try respondMapped(&request, allocator, .malformed_request, context);
            return;
        };
        if (first_line_end > maximum_request_line_bytes or
            (request.head.content_length orelse 0) > maximum_body_bytes)
        {
            try respondMapped(&request, allocator, .malformed_request, context);
            return;
        }
        const method = canonicalMethod(request.head.method) orelse {
            try respondMapped(&request, allocator, .method_not_allowed, context);
            return;
        };
        var response = try dispatch(allocator, route, .{
            .method = method,
            .path = request.head.target,
        }, context);
        defer response.deinit();
        request.respond(response.body, .{
            .status = @enumFromInt(response.status),
            .reason = response.reason,
            .keep_alive = false,
            .extra_headers = &.{.{ .name = "content-type", .value = content_type }},
        }) catch |err| {
            if (socket_writer.err) |write_error| if (write_error == error.Canceled) return error.Canceled;
            return err;
        };
        _ = stream.shutdown(io, .both) catch |err| if (err == error.Canceled) return error.Canceled;
    }
};

fn canonicalMethod(method: std.http.Method) ?[]const u8 {
    return switch (method) {
        .GET => "get",
        .POST => "post",
        .PUT => "put",
        .DELETE => "delete",
        .PATCH => "patch",
        .HEAD => "head",
        .OPTIONS => "options",
        .CONNECT => "connect",
        .TRACE => "trace",
    };
}

fn respondMapped(
    request: *std.http.Server.Request,
    allocator: std.mem.Allocator,
    kind: error_mapping.Kind,
    context: *DispatchContext,
) !void {
    var request_id_storage: [36]u8 = undefined;
    const generated_request_id = try requestId(context.io, &request_id_storage);
    var response = try failureResponse(allocator, generated_request_id, kind);
    defer response.deinit();
    try request.respond(response.body, .{
        .status = @enumFromInt(response.status),
        .reason = response.reason,
        .keep_alive = false,
        .extra_headers = &.{.{ .name = "content-type", .value = content_type }},
    });
}

fn writeMappedRaw(
    stream: std.Io.net.Stream,
    io: std.Io,
    allocator: std.mem.Allocator,
    kind: error_mapping.Kind,
    context: *DispatchContext,
) !void {
    var request_id_storage: [36]u8 = undefined;
    const generated_request_id = try requestId(context.io, &request_id_storage);
    var response = try failureResponse(allocator, generated_request_id, kind);
    defer response.deinit();
    var buffer: [4096]u8 = undefined;
    var writer = stream.writer(io, &buffer);
    try writer.interface.print(
        "HTTP/1.1 {d} {s}\r\ncontent-type: {s}\r\ncontent-length: {d}\r\nconnection: close\r\n\r\n",
        .{ response.status, response.reason, content_type, response.body.len },
    );
    try writer.interface.writeAll(response.body);
    try writer.interface.flush();
    _ = stream.shutdown(io, .both) catch |err| if (err == error.Canceled) return error.Canceled;
}
