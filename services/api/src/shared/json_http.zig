const std = @import("std");
const entity_module = @import("entity_id.zig");
const request_module = @import("request_id.zig");
const currency_module = @import("currency.zig");
const money_module = @import("money.zig");
const date_module = @import("local_date.zig");
const instant_module = @import("utc_instant.zig");
const digest_module = @import("digest.zig");
const shared_coverage = @import("shared_coverage_probe");

pub const ConversionError = error{
    WrongType,
    UnknownField,
    DuplicateField,
    MissingField,
    TrailingContent,
    InvalidValue,
    OutOfMemory,
};

const WireMoney = struct {
    currency: []const u8,
    minor_units: []const u8,
};

pub fn parseEntityIdJson(allocator: std.mem.Allocator, input: []const u8) ConversionError!entity_module.EntityId {
    const text = try parseJsonString(allocator, input);
    defer allocator.free(text);
    return entity_module.EntityId.parse(text) catch ConversionError.InvalidValue;
}

pub fn parseRequestIdJson(allocator: std.mem.Allocator, input: []const u8) ConversionError!request_module.RequestId {
    const text = try parseJsonString(allocator, input);
    defer allocator.free(text);
    return request_module.RequestId.parse(text) catch ConversionError.InvalidValue;
}

pub fn parseCurrencyJson(allocator: std.mem.Allocator, input: []const u8) ConversionError!currency_module.Currency {
    const text = try parseJsonString(allocator, input);
    defer allocator.free(text);
    return currency_module.Currency.parse(text) catch ConversionError.InvalidValue;
}

pub fn parseLocalDateJson(allocator: std.mem.Allocator, input: []const u8) ConversionError!date_module.LocalDate {
    const text = try parseJsonString(allocator, input);
    defer allocator.free(text);
    return date_module.LocalDate.parse(text) catch ConversionError.InvalidValue;
}

pub fn parseUtcInstantJson(allocator: std.mem.Allocator, input: []const u8) ConversionError!instant_module.UtcInstant {
    const text = try parseJsonString(allocator, input);
    defer allocator.free(text);
    return instant_module.UtcInstant.parse(text) catch ConversionError.InvalidValue;
}

pub fn parseSha256DigestJson(allocator: std.mem.Allocator, input: []const u8) ConversionError!digest_module.Sha256Digest {
    const text = try parseJsonString(allocator, input);
    defer allocator.free(text);
    return digest_module.Sha256Digest.parse(text) catch ConversionError.InvalidValue;
}

pub fn parseCanonicalInt64Json(allocator: std.mem.Allocator, input: []const u8) ConversionError!i64 {
    const text = try parseJsonString(allocator, input);
    defer allocator.free(text);
    return money_module.parseCanonicalInt64(text) catch ConversionError.InvalidValue;
}

pub fn parseMoneyJson(allocator: std.mem.Allocator, input: []const u8) ConversionError!money_module.Money {
    var parsed = std.json.parseFromSlice(WireMoney, allocator, input, .{}) catch |err| return mapJsonError(err);
    defer parsed.deinit();
    return .{
        .currency = currency_module.Currency.parse(parsed.value.currency) catch return ConversionError.InvalidValue,
        .minor_units = money_module.parseCanonicalInt64(parsed.value.minor_units) catch return ConversionError.InvalidValue,
    };
}

pub fn formatEntityIdJson(value: entity_module.EntityId, output: *[38]u8) []const u8 {
    output[0] = '"';
    _ = value.formatInto(output[1..37]);
    output[37] = '"';
    return output;
}

pub fn formatRequestIdJson(value: request_module.RequestId, output: *[38]u8) []const u8 {
    output[0] = '"';
    _ = value.formatInto(output[1..37]);
    output[37] = '"';
    return output;
}

pub fn formatCurrencyJson(value: currency_module.Currency, output: *[5]u8) []const u8 {
    output.* = .{ '"', value.bytes[0], value.bytes[1], value.bytes[2], '"' };
    return output;
}

pub fn formatLocalDateJson(value: date_module.LocalDate, output: *[12]u8) []const u8 {
    output[0] = '"';
    _ = value.formatInto(output[1..11]);
    output[11] = '"';
    return output;
}

pub fn formatUtcInstantJson(value: instant_module.UtcInstant, output: *[26]u8) []const u8 {
    output[0] = '"';
    _ = value.formatInto(output[1..25]);
    output[25] = '"';
    return output;
}

pub fn formatSha256DigestJson(value: digest_module.Sha256Digest, output: *[73]u8) []const u8 {
    output[0] = '"';
    _ = value.formatInto(output[1..72]);
    output[72] = '"';
    return output;
}

pub fn formatCanonicalInt64Json(value: i64, output: *[22]u8) []const u8 {
    output[0] = '"';
    var decimal: [20]u8 = undefined;
    const text = money_module.formatCanonicalInt64(value, &decimal);
    @memcpy(output[1 .. text.len + 1], text);
    output[text.len + 1] = '"';
    return output[0 .. text.len + 2];
}

pub fn formatMoneyJson(value: money_module.Money, output: *[64]u8) []const u8 {
    var decimal: [20]u8 = undefined;
    const minor_units = money_module.formatCanonicalInt64(value.minor_units, &decimal);
    return std.fmt.bufPrint(
        output,
        "{{\"currency\":\"{s}\",\"minor_units\":\"{s}\"}}",
        .{ value.currency.bytes[0..], minor_units },
    ) catch unreachable;
}

pub fn parseRequestIdHeader(text: []const u8) request_module.ParseError!request_module.RequestId {
    return request_module.RequestId.parse(text);
}

fn parseJsonString(allocator: std.mem.Allocator, input: []const u8) ConversionError![]u8 {
    var parsed = std.json.parseFromSlice([]const u8, allocator, input, .{ .allocate = .alloc_always }) catch |err| return mapJsonError(err);
    defer parsed.deinit();
    return allocator.dupe(u8, parsed.value) catch ConversionError.OutOfMemory;
}

fn mapJsonError(err: anyerror) ConversionError {
    return switch (err) {
        error.DuplicateField => blk: {
            shared_coverage.hit(.json_duplicate_field);
            break :blk ConversionError.DuplicateField;
        },
        error.UnknownField => blk: {
            shared_coverage.hit(.json_unknown_field);
            break :blk ConversionError.UnknownField;
        },
        error.MissingField => blk: {
            shared_coverage.hit(.json_missing_field);
            break :blk ConversionError.MissingField;
        },
        error.OutOfMemory => ConversionError.OutOfMemory,
        error.SyntaxError, error.UnexpectedEndOfInput => blk: {
            shared_coverage.hit(.json_trailing_content);
            break :blk ConversionError.TrailingContent;
        },
        else => blk: {
            shared_coverage.hit(.json_wrong_type);
            break :blk ConversionError.WrongType;
        },
    };
}
