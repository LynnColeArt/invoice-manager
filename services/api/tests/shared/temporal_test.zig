const std = @import("std");
const shared = @import("shared");

test "LocalDate applies Gregorian rules and exact formatting" {
    for ([_][]const u8{ "0001-01-01", "2000-02-29", "2024-02-29", "9999-12-31" }) |text| {
        const value = try shared.LocalDate.parse(text);
        var output: [10]u8 = undefined;
        try std.testing.expectEqualSlices(u8, text, value.formatInto(&output));
    }
    for ([_][]const u8{ "0000-01-01", "1900-02-29", "2100-02-29", "2024-00-01", "2024-04-31" }) |text| {
        try std.testing.expectError(shared.LocalDateParseError.InvalidDate, shared.LocalDate.parse(text));
    }
    try std.testing.expectError(shared.LocalDateParseError.InvalidShape, shared.LocalDate.parse("2024-2-9"));
}

test "UtcInstant is exact UTC milliseconds independent of process timezone" {
    const cases = [_][]const u8{
        "1970-01-01T00:00:00.000Z",
        "2024-02-29T12:34:56.001Z",
        "2030-06-15T23:59:59.999Z",
    };
    for (cases) |text| {
        const value = try shared.UtcInstant.parse(text);
        var output: [24]u8 = undefined;
        try std.testing.expectEqualSlices(u8, text, value.formatInto(&output));
    }
    try std.testing.expectError(shared.UtcInstantParseError.InvalidShape, shared.UtcInstant.parse("2024-01-01T00:00:00Z"));
    try std.testing.expectError(shared.UtcInstantParseError.InvalidDate, shared.UtcInstant.parse("2024-02-30T00:00:00.000Z"));
    try std.testing.expectError(shared.UtcInstantParseError.InvalidClock, shared.UtcInstant.parse("2024-01-01T24:00:00.000Z"));
    try std.testing.expectError(shared.UtcInstantParseError.InvalidClock, shared.UtcInstant.parse("2024-01-01T23:59:60.000Z"));
}
