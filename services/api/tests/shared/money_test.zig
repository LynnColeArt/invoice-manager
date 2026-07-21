const std = @import("std");
const shared = @import("shared");

test "Currency is structural and open to synthetic codes" {
    const zzz = try shared.Currency.parse("ZZZ");
    var output: [3]u8 = undefined;
    try std.testing.expectEqualSlices(u8, "ZZZ", zzz.formatInto(&output));
    try std.testing.expectError(shared.CurrencyParseError.InvalidLength, shared.Currency.parse("US"));
    try std.testing.expectError(shared.CurrencyParseError.InvalidAlphabet, shared.Currency.parse("usd"));
    try std.testing.expectError(shared.CurrencyParseError.InvalidAlphabet, shared.Currency.parse("U1D"));
}

test "canonical signed i64 parsing and formatting is exact" {
    const cases = [_]struct { text: []const u8, value: i64 }{
        .{ .text = "-9223372036854775808", .value = std.math.minInt(i64) },
        .{ .text = "-9007199254740993", .value = -9007199254740993 },
        .{ .text = "0", .value = 0 },
        .{ .text = "9007199254740993", .value = 9007199254740993 },
        .{ .text = "9223372036854775807", .value = std.math.maxInt(i64) },
    };
    for (cases) |case| {
        try std.testing.expectEqual(case.value, try shared.parseCanonicalInt64(case.text));
        var output: [20]u8 = undefined;
        try std.testing.expectEqualSlices(u8, case.text, shared.formatCanonicalInt64(case.value, &output));
    }
    for ([_][]const u8{ "", "+1", "01", "-0", "1.0", "1e3", " 1" }) |text| {
        try std.testing.expectError(shared.MoneyDecimalError.InvalidDecimal, shared.parseCanonicalInt64(text));
    }
    try std.testing.expectError(shared.MoneyDecimalError.Overflow, shared.parseCanonicalInt64("9223372036854775808"));
    try std.testing.expectError(shared.MoneyDecimalError.Overflow, shared.parseCanonicalInt64("-9223372036854775809"));
}

test "Money checked arithmetic keeps signed values and currency exact" {
    const usd = try shared.Currency.parse("USD");
    const eur = try shared.Currency.parse("EUR");
    const negative = shared.Money{ .currency = usd, .minor_units = -10 };
    try std.testing.expectEqual(@as(i64, -7), (try negative.add(.{ .currency = usd, .minor_units = 3 })).minor_units);
    try std.testing.expectEqual(@as(i64, -13), (try negative.sub(.{ .currency = usd, .minor_units = 3 })).minor_units);
    try std.testing.expectError(shared.MoneyArithmeticError.CurrencyMismatch, negative.add(.{ .currency = eur, .minor_units = 3 }));
    try std.testing.expectError(shared.MoneyArithmeticError.Overflow, (shared.Money{ .currency = usd, .minor_units = std.math.maxInt(i64) }).add(.{ .currency = usd, .minor_units = 1 }));
    try std.testing.expectError(shared.MoneyArithmeticError.Overflow, (shared.Money{ .currency = usd, .minor_units = std.math.minInt(i64) }).sub(.{ .currency = usd, .minor_units = 1 }));
}
