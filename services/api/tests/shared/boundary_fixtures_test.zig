const std = @import("std");
const shared = @import("shared");

test "all declared valid boundary fixture cases are visited and accepted" {
    const fixture = try readFixture("../../contracts/fixtures/p0/v1/valid/common-boundaries.json");
    defer std.testing.allocator.free(fixture);
    var document = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, fixture, .{});
    defer document.deinit();
    const root = document.value.object;
    const cases = root.get("cases").?.array.items;
    const required = root.get("required_case_ids").?.array.items;
    const declared_total: usize = @intCast(root.get("case_counts").?.object.get("total").?.integer);
    try std.testing.expectEqual(@as(usize, 42), declared_total);
    try std.testing.expectEqual(declared_total, cases.len);
    try std.testing.expectEqual(declared_total, required.len);
    try assertRequiredCasesVisited(required, cases);
    try assertDefinitionCounts(root, cases, &.{ "CanonicalInt64", "CurrencyCode", "EntityId", "LocalDate", "Money", "NonNegativeInt64", "RequestId", "Sha256Digest", "UtcInstant" });

    var saw_negative_money = false;
    var saw_open_currency = false;
    var saw_exact_milliseconds = false;
    var visited: usize = 0;
    for (cases) |case| {
        const object = case.object;
        const case_id = object.get("case_id").?.string;
        const definition = object.get("definition").?.string;
        try std.testing.expectEqualStrings("valid", object.get("expectation").?.string);
        try std.testing.expect(acceptsFixture(definition, object.get("value").?));
        saw_negative_money = saw_negative_money or std.mem.eql(u8, case_id, "money-negative");
        saw_open_currency = saw_open_currency or std.mem.eql(u8, case_id, "money-zzz-open-currency");
        saw_exact_milliseconds = saw_exact_milliseconds or std.mem.eql(u8, case_id, "utc-instant-millisecond-999");
        visited += 1;
    }
    try std.testing.expectEqual(declared_total, visited);
    try std.testing.expect(saw_negative_money and saw_open_currency and saw_exact_milliseconds);
}

test "all declared invalid boundary fixture cases are visited and rejected" {
    const fixture = try readFixture("../../contracts/fixtures/p0/v1/invalid/common-boundaries.json");
    defer std.testing.allocator.free(fixture);
    var document = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, fixture, .{});
    defer document.deinit();
    const root = document.value.object;
    const cases = root.get("cases").?.array.items;
    const required = root.get("required_case_ids").?.array.items;
    const declared_total: usize = @intCast(root.get("case_counts").?.object.get("total").?.integer);
    try std.testing.expectEqual(@as(usize, 73), declared_total);
    try std.testing.expectEqual(declared_total, cases.len);
    try std.testing.expectEqual(declared_total, required.len);
    try assertRequiredCasesVisited(required, cases);
    try assertDefinitionCounts(root, cases, &.{ "CanonicalInt64", "EntityId", "LocalDate", "Money", "NonNegativeInt64", "RequestId", "Sha256Digest", "UtcInstant" });

    var runtime_cases: usize = 0;
    var saw_overflow = false;
    var saw_underflow = false;
    for (cases) |case| {
        const object = case.object;
        const case_id = object.get("case_id").?.string;
        const definition = object.get("definition").?.string;
        const value = object.get("value").?;
        try std.testing.expectEqualStrings("invalid", object.get("expectation").?.string);
        try std.testing.expect(!acceptsFixture(definition, value));
        const layer = object.get("expected").?.object.get("validation_layer").?.string;
        if (std.mem.eql(u8, layer, "runtime")) {
            runtime_cases += 1;
            try std.testing.expect(runtimeShapeAccepts(definition, value));
        }
        saw_overflow = saw_overflow or std.mem.eql(u8, case_id, "canonical-int64-i64-overflow");
        saw_underflow = saw_underflow or std.mem.eql(u8, case_id, "canonical-int64-i64-underflow");
    }
    try std.testing.expectEqual(@as(usize, 8), runtime_cases);
    try std.testing.expect(saw_overflow and saw_underflow);
}

fn acceptsFixture(definition: []const u8, value: std.json.Value) bool {
    if (std.mem.eql(u8, definition, "EntityId")) return parseString(shared.EntityId, value);
    if (std.mem.eql(u8, definition, "RequestId")) return parseString(shared.RequestId, value);
    if (std.mem.eql(u8, definition, "CurrencyCode")) return parseString(shared.Currency, value);
    if (std.mem.eql(u8, definition, "LocalDate")) return parseString(shared.LocalDate, value);
    if (std.mem.eql(u8, definition, "UtcInstant")) return parseString(shared.UtcInstant, value);
    if (std.mem.eql(u8, definition, "Sha256Digest")) return parseString(shared.Sha256Digest, value);
    if (std.mem.eql(u8, definition, "CanonicalInt64")) {
        const text = switch (value) {
            .string => |text| text,
            else => return false,
        };
        _ = shared.parseCanonicalInt64(text) catch return false;
        return true;
    }
    if (std.mem.eql(u8, definition, "NonNegativeInt64")) {
        const text = switch (value) {
            .string => |text| text,
            else => return false,
        };
        const integer = shared.parseCanonicalInt64(text) catch return false;
        return integer >= 0;
    }
    if (std.mem.eql(u8, definition, "Money")) {
        const object = switch (value) {
            .object => |object| object,
            else => return false,
        };
        if (object.count() != 2) return false;
        const currency_value = object.get("currency") orelse return false;
        const minor_value = object.get("minor_units") orelse return false;
        const currency_text = switch (currency_value) {
            .string => |text| text,
            else => return false,
        };
        const minor_text = switch (minor_value) {
            .string => |text| text,
            else => return false,
        };
        _ = shared.Currency.parse(currency_text) catch return false;
        _ = shared.parseCanonicalInt64(minor_text) catch return false;
        return true;
    }
    return false;
}

fn parseString(comptime ValueType: type, value: std.json.Value) bool {
    const text = switch (value) {
        .string => |text| text,
        else => return false,
    };
    _ = ValueType.parse(text) catch return false;
    return true;
}

fn runtimeShapeAccepts(definition: []const u8, value: std.json.Value) bool {
    if (std.mem.eql(u8, definition, "CanonicalInt64") or std.mem.eql(u8, definition, "NonNegativeInt64")) {
        const text = switch (value) {
            .string => |text| text,
            else => return false,
        };
        return canonicalIntegerShape(text, std.mem.eql(u8, definition, "NonNegativeInt64"));
    }
    if (std.mem.eql(u8, definition, "LocalDate")) {
        const text = switch (value) {
            .string => |text| text,
            else => return false,
        };
        return dateShape(text);
    }
    if (std.mem.eql(u8, definition, "UtcInstant")) {
        const text = switch (value) {
            .string => |text| text,
            else => return false,
        };
        return instantShape(text);
    }
    if (std.mem.eql(u8, definition, "Money")) {
        const object = switch (value) {
            .object => |object| object,
            else => return false,
        };
        const currency = object.get("currency") orelse return false;
        const minor = object.get("minor_units") orelse return false;
        return currency == .string and currency.string.len == 3 and minor == .string and canonicalIntegerShape(minor.string, false);
    }
    return false;
}

fn canonicalIntegerShape(text: []const u8, nonnegative: bool) bool {
    if (text.len == 0) return false;
    var index: usize = 0;
    if (text[0] == '-') {
        if (nonnegative or text.len == 1 or text[1] == '0') return false;
        index = 1;
    } else if (text[0] == '0') return text.len == 1;
    while (index < text.len) : (index += 1) if (text[index] < '0' or text[index] > '9') return false;
    return true;
}

fn dateShape(text: []const u8) bool {
    if (text.len != 10 or text[4] != '-' or text[7] != '-') return false;
    for (text, 0..) |byte, index| if (index != 4 and index != 7 and (byte < '0' or byte > '9')) return false;
    return true;
}

fn instantShape(text: []const u8) bool {
    if (text.len != 24 or text[4] != '-' or text[7] != '-' or text[10] != 'T' or text[13] != ':' or text[16] != ':' or text[19] != '.' or text[23] != 'Z') return false;
    for (text, 0..) |byte, index| switch (index) {
        4, 7, 10, 13, 16, 19, 23 => {},
        else => if (byte < '0' or byte > '9') return false,
    };
    return true;
}

fn assertRequiredCasesVisited(required: []const std.json.Value, cases: []const std.json.Value) !void {
    for (required, 0..) |required_value, required_index| {
        const required_id = required_value.string;
        for (required[0..required_index]) |prior| try std.testing.expect(!std.mem.eql(u8, required_id, prior.string));
        var found = false;
        for (cases) |case| found = found or std.mem.eql(u8, required_id, case.object.get("case_id").?.string);
        try std.testing.expect(found);
    }
}

fn readFixture(path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(std.testing.io, path, std.testing.allocator, .limited(1024 * 1024));
}

fn assertDefinitionCounts(root: std.json.ObjectMap, cases: []const std.json.Value, definitions: []const []const u8) !void {
    const declared = root.get("case_counts").?.object.get("by_definition").?.object;
    try std.testing.expectEqual(definitions.len, declared.count());
    for (definitions) |definition| {
        var visited: usize = 0;
        for (cases) |case| visited += @intFromBool(std.mem.eql(u8, definition, case.object.get("definition").?.string));
        try std.testing.expect(visited > 0);
        try std.testing.expectEqual(@as(usize, @intCast(declared.get(definition).?.integer)), visited);
    }
}
