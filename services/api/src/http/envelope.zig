const std = @import("std");

pub const maximum_error_message_bytes = 160;
pub const maximum_field_failures = 16;

pub const FieldFailure = struct {
    path: []const u8,
    code: []const u8,
    message: []const u8,
};

pub const EnvelopeError = error{
    InvalidRequestId,
    InvalidErrorCode,
    InvalidFieldPath,
    MessageTooLong,
    TooManyFieldFailures,
};

pub fn successReady(
    allocator: std.mem.Allocator,
    request_id: []const u8,
) (EnvelopeError || std.mem.Allocator.Error)![]u8 {
    try validateRequestId(request_id);
    return std.fmt.allocPrint(
        allocator,
        "{{\"data\":{{\"status\":\"ready\"}},\"meta\":{{\"request_id\":\"{s}\"}}}}",
        .{request_id},
    );
}

pub fn failure(
    allocator: std.mem.Allocator,
    request_id: []const u8,
    code: []const u8,
    message: []const u8,
    fields: []const FieldFailure,
) (EnvelopeError || std.mem.Allocator.Error)![]u8 {
    try validateRequestId(request_id);
    try validateCode(code);
    if (message.len > maximum_error_message_bytes) return error.MessageTooLong;
    if (fields.len > maximum_field_failures) return error.TooManyFieldFailures;

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendSlice(allocator, "{\"error\":{\"code\":");
    try appendJsonString(&output, allocator, code);
    try output.appendSlice(allocator, ",\"message\":");
    try appendJsonString(&output, allocator, message);
    if (fields.len != 0) {
        try output.appendSlice(allocator, ",\"fields\":[");
        for (fields, 0..) |field, index| {
            try validatePointer(field.path);
            try validateCode(field.code);
            if (field.message.len > maximum_error_message_bytes) return error.MessageTooLong;
            if (index != 0) try output.append(allocator, ',');
            try output.appendSlice(allocator, "{\"path\":");
            try appendJsonString(&output, allocator, field.path);
            try output.appendSlice(allocator, ",\"code\":");
            try appendJsonString(&output, allocator, field.code);
            try output.appendSlice(allocator, ",\"message\":");
            try appendJsonString(&output, allocator, field.message);
            try output.append(allocator, '}');
        }
        try output.append(allocator, ']');
    }
    try output.appendSlice(allocator, "},\"meta\":{\"request_id\":");
    try appendJsonString(&output, allocator, request_id);
    try output.appendSlice(allocator, "}}");
    return output.toOwnedSlice(allocator);
}

fn validateRequestId(value: []const u8) EnvelopeError!void {
    _ = @import("shared").RequestId.parse(value) catch return error.InvalidRequestId;
}

fn validateCode(value: []const u8) EnvelopeError!void {
    if (value.len == 0 or value.len > 64) return error.InvalidErrorCode;
    for (value, 0..) |byte, index| {
        if ((byte >= 'a' and byte <= 'z') or (index != 0 and byte >= '0' and byte <= '9') or
            (index != 0 and byte == '_')) continue;
        return error.InvalidErrorCode;
    }
}

fn validatePointer(value: []const u8) EnvelopeError!void {
    if (value.len == 0) return;
    if (value[0] != '/' or value.len > 256) return error.InvalidFieldPath;
    var index: usize = 0;
    while (index < value.len) : (index += 1) {
        if (value[index] != '~') continue;
        if (index + 1 >= value.len or (value[index + 1] != '0' and value[index + 1] != '1')) {
            return error.InvalidFieldPath;
        }
        index += 1;
    }
}

fn appendJsonString(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    value: []const u8,
) std.mem.Allocator.Error!void {
    try output.append(allocator, '"');
    for (value) |byte| switch (byte) {
        '"' => try output.appendSlice(allocator, "\\\""),
        '\\' => try output.appendSlice(allocator, "\\\\"),
        '\n' => try output.appendSlice(allocator, "\\n"),
        '\r' => try output.appendSlice(allocator, "\\r"),
        '\t' => try output.appendSlice(allocator, "\\t"),
        0...8, 11...12, 14...0x1f => try output.appendSlice(allocator, "?"),
        else => try output.append(allocator, byte),
    };
    try output.append(allocator, '"');
}
