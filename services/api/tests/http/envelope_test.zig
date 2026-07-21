const std = @import("std");
const envelope = @import("http").envelope;
const error_mapping = @import("http").error_mapping;

const request_id = "018f6f10-7b7a-7000-8000-000000000001";

test "success and mapped failures are closed mutually-exclusive envelopes" {
    const success = try envelope.successReady(std.testing.allocator, request_id);
    defer std.testing.allocator.free(success);
    try std.testing.expect(std.mem.indexOf(u8, success, "\"data\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, success, "\"error\"") == null);
    inline for (.{ error_mapping.Kind.malformed_request, .not_found, .method_not_allowed, .internal, .not_ready }) |kind| {
        const mapped = error_mapping.map(kind);
        const body = try envelope.failure(std.testing.allocator, request_id, mapped.code, mapped.message, &.{});
        defer std.testing.allocator.free(body);
        try std.testing.expect(std.mem.indexOf(u8, body, "\"error\"") != null);
        try std.testing.expect(std.mem.indexOf(u8, body, "\"data\"") == null);
        try std.testing.expect(std.mem.indexOf(u8, body, request_id) != null);
    }
}

test "field failures require logical JSON Pointer paths and bounded safe output" {
    const body = try envelope.failure(std.testing.allocator, request_id, "invalid_request", "Validation failed.", &.{.{
        .path = "/client/name",
        .code = "required",
        .message = "A value is required.",
    }});
    defer std.testing.allocator.free(body);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"path\":\"/client/name\"") != null);
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
