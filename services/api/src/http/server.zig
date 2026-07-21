const std = @import("std");
const envelope = @import("envelope.zig");
const error_mapping = @import("error_mapping.zig");
const route_inventory = @import("route_inventory.zig");
const route_policy = @import("route_policy.zig");

pub const maximum_header_bytes = 16 * 1024;
pub const maximum_request_line_bytes = 2 * 1024;
pub const maximum_body_bytes = 16 * 1024;
pub const content_type = "application/json; charset=utf-8";
pub const header_read_timeout = std.Io.Clock.Duration{
    .raw = .fromSeconds(2),
    .clock = .awake,
};

pub const Request = struct {
    method: []const u8,
    path: []const u8,
};

pub const DispatchContext = struct {
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
    inventory: *const route_inventory.Inventory,
    bindings: []const route_inventory.HandlerBinding,
    request: Request,
    context: *DispatchContext,
) !Response {
    var request_id_storage: [36]u8 = undefined;
    const generated_request_id = try requestId(context.io, &request_id_storage);

    const resolved = switch (route_inventory.resolve(inventory, bindings, request.method, request.path)) {
        .found => |value| value,
        .method_not_allowed => return failureResponse(allocator, generated_request_id, .method_not_allowed),
        .not_found => return failureResponse(allocator, generated_request_id, .not_found),
    };
    if (route_policy.classify(resolved.route) != .public) {
        return failureResponse(allocator, generated_request_id, .not_found);
    }

    context.handler_calls.* += 1;
    const body = resolved.binding.handler(allocator, generated_request_id) catch
        return failureResponse(allocator, generated_request_id, .internal);
    return .{
        .allocator = allocator,
        .status = 200,
        .reason = "OK",
        .body = body,
    };
}

pub fn notReadyResponse(allocator: std.mem.Allocator, io: std.Io) !Response {
    var request_id_storage: [36]u8 = undefined;
    const generated_request_id = try requestId(io, &request_id_storage);
    return failureResponse(allocator, generated_request_id, .not_ready);
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

    /// The composition root calls this only after it has consumed the typed
    /// WP06/WP07 readiness results. This module has no dependency capability
    /// with which to mint or bypass persistence readiness.
    pub fn listen(
        io: std.Io,
        bind_address_value: std.Io.net.IpAddress,
        _: *const ReadyContext,
    ) !Listener {
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
        inventory: *const route_inventory.Inventory,
        bindings: []const route_inventory.HandlerBinding,
        context: *DispatchContext,
    ) error{Canceled}!ServeOutcome {
        const stream = self.server.accept(io) catch |err| switch (err) {
            error.Canceled => return error.Canceled,
            else => return .accept_failed,
        };
        defer stream.close(io);

        var read_buffer: [maximum_header_bytes]u8 = undefined;
        var socket_reader = stream.reader(io, &read_buffer);
        var write_buffer: [4096]u8 = undefined;
        var socket_writer = stream.writer(io, &write_buffer);
        var http_server = std.http.Server.init(&socket_reader.interface, &socket_writer.interface);
        var select_buffer: [2]HeaderSelect = undefined;
        var select = std.Io.Select(HeaderSelect).init(io, &select_buffer);
        select.async(.head, receiveHead, .{ &http_server, &socket_reader });
        select.async(.timeout, waitHeaderTimeout, .{io});
        const selected = select.await() catch |err| switch (err) {
            error.Canceled => {
                select.cancelDiscard();
                return error.Canceled;
            },
        };
        select.cancelDiscard();
        var request = switch (selected) {
            .timeout => return .header_timeout,
            .head => |result| switch (result) {
                .request => |value| value,
                .canceled => return error.Canceled,
                .invalid => {
                    writeMappedRaw(stream, io, allocator, .malformed_request, context) catch |err| switch (err) {
                        error.Canceled => return error.Canceled,
                        else => return .disconnected,
                    };
                    return .malformed;
                },
            },
        };

        const first_line_end = std.mem.indexOf(u8, request.head_buffer, "\r\n") orelse {
            respondMapped(&request, allocator, .malformed_request, context) catch return .disconnected;
            return .malformed;
        };
        if (first_line_end > maximum_request_line_bytes or
            (request.head.content_length orelse 0) > maximum_body_bytes)
        {
            respondMapped(&request, allocator, .malformed_request, context) catch return .disconnected;
            return .malformed;
        }
        if (request.head.transfer_encoding != .none or
            (request.head.content_length != null and request.head.transfer_encoding != .none))
        {
            respondMapped(&request, allocator, .malformed_request, context) catch return .disconnected;
            return .malformed;
        }
        const method = canonicalMethod(request.head.method) orelse {
            respondMapped(&request, allocator, .method_not_allowed, context) catch return .disconnected;
            return .served;
        };
        var response = dispatch(allocator, inventory, bindings, .{
            .method = method,
            .path = request.head.target,
        }, context) catch {
            respondMapped(&request, allocator, .internal, context) catch return .disconnected;
            return .served;
        };
        defer response.deinit();
        request.respond(response.body, .{
            .status = @enumFromInt(response.status),
            .reason = response.reason,
            .keep_alive = false,
            .extra_headers = &.{.{ .name = "content-type", .value = content_type }},
        }) catch {
            if (socket_writer.err) |write_error| if (write_error == error.Canceled) return error.Canceled;
            return .disconnected;
        };
        stream.shutdown(io, .both) catch |err| switch (err) {
            error.Canceled => return error.Canceled,
            else => return .disconnected,
        };
        return .served;
    }
};

pub const ServeOutcome = enum {
    served,
    malformed,
    disconnected,
    header_timeout,
    accept_failed,
};

/// An opaque capability consumed only while constructing the listener. The
/// HTTP package cannot mint it from a boolean or dependency state.
pub const ReadyContext = opaque {};

const ReceiveHeadResult = union(enum) {
    request: std.http.Server.Request,
    invalid,
    canceled,
};

const HeaderSelect = union(enum) {
    head: ReceiveHeadResult,
    timeout: void,
};

fn receiveHead(
    http_server: *std.http.Server,
    socket_reader: *std.Io.net.Stream.Reader,
) ReceiveHeadResult {
    return .{ .request = http_server.receiveHead() catch {
        if (socket_reader.err) |read_error| if (read_error == error.Canceled) return .canceled;
        return .invalid;
    } };
}

fn waitHeaderTimeout(io: std.Io) void {
    header_read_timeout.sleep(io) catch {};
}

fn canonicalMethod(method: std.http.Method) ?[]const u8 {
    return switch (method) {
        .GET => "get",
        .POST => "post",
        .PUT => "put",
        .DELETE => "delete",
        .PATCH => "patch",
        .HEAD => "head",
        .OPTIONS => "options",
        .CONNECT => null,
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
