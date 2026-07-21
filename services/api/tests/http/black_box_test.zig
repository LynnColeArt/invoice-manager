const std = @import("std");
const fixture = @import("process_fixture.zig");
const http_test_config = @import("http_test_config");
const shared = @import("shared");

const get_health = "GET /api/v1/health HTTP/1.1\r\nhost: 127.0.0.1\r\nconnection: close\r\n\r\n";

const ParsedResponse = struct {
    head: []const u8,
    body: []const u8,
};

fn parseResponse(bytes: []const u8) !ParsedResponse {
    const boundary = std.mem.indexOf(u8, bytes, "\r\n\r\n") orelse return error.MissingHeaderBoundary;
    return .{ .head = bytes[0..boundary], .body = bytes[boundary + 4 ..] };
}

fn expectStatus(bytes: []const u8, status: u16, reason: []const u8) !ParsedResponse {
    const parsed = try parseResponse(bytes);
    var expected_buffer: [64]u8 = undefined;
    const expected = try std.fmt.bufPrint(&expected_buffer, "HTTP/1.1 {d} {s}", .{ status, reason });
    try std.testing.expect(std.mem.startsWith(u8, parsed.head, expected));
    try std.testing.expect(std.ascii.indexOfIgnoreCase(parsed.head, "content-type: application/json; charset=utf-8") != null);
    try std.testing.expect(std.ascii.indexOfIgnoreCase(parsed.head, "connection: close") != null);
    return parsed;
}

fn expectReadyResponse(bytes: []const u8) !void {
    const response = try expectStatus(bytes, 200, "OK");
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, response.body, .{});
    defer parsed.deinit();
    try std.testing.expect(parsed.value == .object);
    try std.testing.expectEqual(@as(usize, 2), parsed.value.object.count());
    try std.testing.expect(parsed.value.object.get("error") == null);
    const data = parsed.value.object.get("data") orelse return error.MissingData;
    try std.testing.expectEqual(@as(usize, 1), data.object.count());
    try std.testing.expectEqualStrings("ready", data.object.get("status").?.string);
    const meta = parsed.value.object.get("meta") orelse return error.MissingMeta;
    try std.testing.expectEqual(@as(usize, 1), meta.object.count());
    const request_id = meta.object.get("request_id").?.string;
    _ = try shared.RequestId.parse(request_id);
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, response.body, request_id));
}

fn expectFailureCode(bytes: []const u8, status: u16, reason: []const u8, code: []const u8) !void {
    const response = try expectStatus(bytes, status, reason);
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, response.body, .{});
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 2), parsed.value.object.count());
    try std.testing.expect(parsed.value.object.get("data") == null);
    const failure = parsed.value.object.get("error").?.object;
    try std.testing.expectEqualStrings(code, failure.get("code").?.string);
    const request_id = parsed.value.object.get("meta").?.object.get("request_id").?.string;
    _ = try shared.RequestId.parse(request_id);
}

test "spawned service serves the exact health boundary and contains client failures" {
    var service = try fixture.Service.start(std.testing.allocator, std.testing.io);
    defer service.stop(std.testing.io);

    const health = try service.request(get_health);
    defer std.testing.allocator.free(health);
    try expectReadyResponse(health);

    const unknown = try service.request("GET /api/v1/invoices HTTP/1.1\r\nhost: 127.0.0.1\r\nconnection: close\r\n\r\n");
    defer std.testing.allocator.free(unknown);
    try expectFailureCode(unknown, 404, "Not Found", "route_not_found");

    const unsupported = try service.request("POST /api/v1/health HTTP/1.1\r\nhost: 127.0.0.1\r\ncontent-length: 0\r\nconnection: close\r\n\r\n");
    defer std.testing.allocator.free(unsupported);
    try expectFailureCode(unsupported, 405, "Method Not Allowed", "method_not_allowed");

    const malformed = try service.request("not-http\r\n\r\n");
    defer std.testing.allocator.free(malformed);
    try expectFailureCode(malformed, 400, "Bad Request", "malformed_request");

    const ambiguous = try service.request("POST /api/v1/health HTTP/1.1\r\nhost: 127.0.0.1\r\ncontent-length: 0\r\ntransfer-encoding: chunked\r\nconnection: close\r\n\r\n0\r\n\r\n");
    defer std.testing.allocator.free(ambiguous);
    try expectFailureCode(ambiguous, 400, "Bad Request", "malformed_request");

    try service.disconnect("GET /api/v1/health HTTP/1.1\r\nhost:");
    const after_disconnect = try service.request(get_health);
    defer std.testing.allocator.free(after_disconnect);
    try expectReadyResponse(after_disconnect);
}

test "real corrupt-store startup exits safely without bind fallback or replacement" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try std.fmt.allocPrint(
        std.testing.allocator,
        ".zig-cache/tmp/{s}/corrupt-black-box.shovel",
        .{tmp.sub_path},
    );
    defer std.testing.allocator.free(path);
    const corrupt = "synthetic-corrupt-storage-v1\nnot-a-shovelerdb-snapshot\n";
    try std.Io.Dir.writeFile(.cwd(), std.testing.io, .{ .sub_path = path, .data = corrupt });
    const before_file = try std.Io.Dir.openFile(.cwd(), std.testing.io, path, .{});
    const before_stat = try before_file.stat(std.testing.io);
    before_file.close(std.testing.io);

    const address = try fixture.unusedLoopbackAddress(std.testing.io);
    var port_buffer: [5]u8 = undefined;
    const port = try std.fmt.bufPrint(&port_buffer, "{d}", .{address.getPort()});
    var environment = try std.process.Environ.createMap(std.testing.environ, std.testing.allocator);
    defer environment.deinit();
    try environment.put("INVOICE_API_BIND", "127.0.0.1");
    try environment.put("INVOICE_API_PORT", port);
    try environment.put("INVOICE_DATABASE_PATH", path);
    const result = try std.process.run(std.testing.allocator, std.testing.io, .{
        .argv = &.{http_test_config.api_executable_path},
        .environ_map = &environment,
        .timeout = .{ .duration = .{ .raw = .fromSeconds(5), .clock = .awake } },
    });
    defer std.testing.allocator.free(result.stdout);
    defer std.testing.allocator.free(result.stderr);
    try std.testing.expectEqual(std.process.Child.Term{ .exited = 1 }, result.term);
    try std.testing.expectEqualStrings("", result.stdout);
    try std.testing.expectEqualStrings("[api:error] startup failed\n", result.stderr);
    try std.testing.expect(std.mem.indexOf(u8, result.stderr, path) == null);
    try std.testing.expect(std.mem.indexOf(u8, result.stderr, corrupt) == null);
    try std.testing.expect(std.mem.indexOf(u8, result.stderr, "[api:ready]") == null);

    var rebound_address = address;
    var rebound = try rebound_address.listen(std.testing.io, .{ .reuse_address = false });
    rebound.deinit(std.testing.io);
    const after_file = try std.Io.Dir.openFile(.cwd(), std.testing.io, path, .{});
    const after_stat = try after_file.stat(std.testing.io);
    after_file.close(std.testing.io);
    const after = try std.Io.Dir.readFileAlloc(.cwd(), std.testing.io, path, std.testing.allocator, .limited(4096));
    defer std.testing.allocator.free(after);
    try std.testing.expectEqualSlices(u8, corrupt, after);
    try std.testing.expectEqual(before_stat.inode, after_stat.inode);
    try std.testing.expectEqual(before_stat.size, after_stat.size);
}
