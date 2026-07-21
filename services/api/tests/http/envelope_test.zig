const std = @import("std");
const envelope = @import("http").envelope;
const error_mapping = @import("http").error_mapping;
const shared = @import("shared");

const request_id = "018f6f10-7b7a-7000-8000-000000000001";

fn expectExactMeta(value: std.json.Value) !void {
    try std.testing.expect(value == .object);
    try std.testing.expectEqual(@as(usize, 1), value.object.count());
    const id = value.object.get("request_id") orelse return error.MissingRequestId;
    try std.testing.expect(id == .string);
    _ = try shared.RequestId.parse(id.string);
    try std.testing.expectEqualStrings(request_id, id.string);
}

fn expectExactSuccess(body: []const u8) !void {
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, body, .{});
    defer parsed.deinit();
    try std.testing.expect(parsed.value == .object);
    try std.testing.expectEqual(@as(usize, 2), parsed.value.object.count());
    const data = parsed.value.object.get("data") orelse return error.MissingData;
    try std.testing.expect(parsed.value.object.get("error") == null);
    try std.testing.expect(data == .object);
    try std.testing.expectEqual(@as(usize, 1), data.object.count());
    const status = data.object.get("status") orelse return error.MissingStatus;
    try std.testing.expect(status == .string);
    try std.testing.expectEqualStrings("ready", status.string);
    try expectExactMeta(parsed.value.object.get("meta") orelse return error.MissingMeta);
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, body, request_id));
}

fn expectExactFailure(body: []const u8, expected_code: []const u8) !void {
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, body, .{});
    defer parsed.deinit();
    try std.testing.expect(parsed.value == .object);
    try std.testing.expectEqual(@as(usize, 2), parsed.value.object.count());
    try std.testing.expect(parsed.value.object.get("data") == null);
    const failure_value = parsed.value.object.get("error") orelse return error.MissingError;
    try std.testing.expect(failure_value == .object);
    try std.testing.expectEqual(@as(usize, 2), failure_value.object.count());
    const code = failure_value.object.get("code") orelse return error.MissingCode;
    const message = failure_value.object.get("message") orelse return error.MissingMessage;
    try std.testing.expect(code == .string and message == .string);
    try std.testing.expectEqualStrings(expected_code, code.string);
    try std.testing.expect(message.string.len != 0);
    try expectExactMeta(parsed.value.object.get("meta") orelse return error.MissingMeta);
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, body, request_id));
}

test "success and mapped failures are closed mutually-exclusive envelopes" {
    const success = try envelope.successReady(std.testing.allocator, request_id);
    defer std.testing.allocator.free(success);
    try expectExactSuccess(success);
    inline for (.{
        .{ error_mapping.Kind.malformed_request, @as(u16, 400) },
        .{ error_mapping.Kind.not_found, @as(u16, 404) },
        .{ error_mapping.Kind.method_not_allowed, @as(u16, 405) },
        .{ error_mapping.Kind.internal, @as(u16, 500) },
        .{ error_mapping.Kind.not_ready, @as(u16, 503) },
    }) |case| {
        const mapped = error_mapping.map(case[0]);
        try std.testing.expectEqual(case[1], mapped.status);
        const body = try envelope.failure(std.testing.allocator, request_id, mapped.code, mapped.message, &.{});
        defer std.testing.allocator.free(body);
        try expectExactFailure(body, mapped.code);
    }
}

test "field failures require logical JSON Pointer paths and bounded safe output" {
    const body = try envelope.failure(std.testing.allocator, request_id, "invalid_request", "Validation failed.", &.{.{
        .path = "/client/name",
        .code = "required",
        .message = "A value is required.",
    }});
    defer std.testing.allocator.free(body);
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, body, .{});
    defer parsed.deinit();
    const failure_value = parsed.value.object.get("error").?.object;
    try std.testing.expectEqual(@as(usize, 3), failure_value.count());
    const fields = failure_value.get("fields").?;
    try std.testing.expect(fields == .array);
    try std.testing.expectEqual(@as(usize, 1), fields.array.items.len);
    try std.testing.expectEqual(@as(usize, 3), fields.array.items[0].object.count());
    try std.testing.expectEqualStrings("/client/name", fields.array.items[0].object.get("path").?.string);
    try std.testing.expectEqualStrings("required", fields.array.items[0].object.get("code").?.string);
    try std.testing.expectEqualStrings("A value is required.", fields.array.items[0].object.get("message").?.string);
    try std.testing.expectError(error.InvalidFieldPath, envelope.failure(std.testing.allocator, request_id, "invalid_request", "Validation failed.", &.{.{
        .path = "client/name",
        .code = "required",
        .message = "A value is required.",
    }}));
}

test "internal diagnostics are never translated into public response bytes" {
    const hostile = "/secret/database.shovel SQL SELECT stack trace raw-body";
    const mapped = error_mapping.map(.internal);
    const body = try envelope.failure(std.testing.allocator, request_id, mapped.code, mapped.message, &.{});
    defer std.testing.allocator.free(body);
    try std.testing.expect(std.mem.indexOf(u8, body, hostile) == null);
    try std.testing.expect(std.mem.indexOf(u8, body, "/secret/") == null);
}

test "invalid UTF-8 is rejected instead of serialized into a JSON string" {
    try std.testing.expectError(
        error.InvalidUtf8,
        envelope.failure(std.testing.allocator, request_id, "invalid_request", "\xff", &.{}),
    );
}
