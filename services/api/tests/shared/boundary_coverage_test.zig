const std = @import("std");
const shared = @import("shared");

test "shared production declarations are analyzed" {
    std.testing.refAllDecls(shared);
}

test "critical branch: entity_id_length" {
    try exerciseNominal();
    try std.testing.expectError(shared.EntityIdParseError.InvalidLength, shared.EntityId.parse("short"));
}

test "critical branch: entity_id_syntax" {
    try exerciseNominal();
    try std.testing.expectError(shared.EntityIdParseError.InvalidSyntax, shared.EntityId.parse("01890F3E-2C4A-7D5E-8ABC-0123456789AB"));
}

test "critical branch: entity_id_version" {
    try exerciseNominal();
    try std.testing.expectError(shared.EntityIdParseError.InvalidVersion, shared.EntityId.parse("01890f3e-2c4a-6d5e-8abc-0123456789ab"));
}

test "critical branch: entity_id_variant" {
    try exerciseNominal();
    try std.testing.expectError(shared.EntityIdParseError.InvalidVariant, shared.EntityId.parse("01890f3e-2c4a-7d5e-7abc-0123456789ab"));
}

test "critical branch: currency_length" {
    try exerciseNominal();
    try std.testing.expectError(shared.CurrencyParseError.InvalidLength, shared.Currency.parse("US"));
}

test "critical branch: currency_alphabet" {
    try exerciseNominal();
    try std.testing.expectError(shared.CurrencyParseError.InvalidAlphabet, shared.Currency.parse("usd"));
}

test "critical branch: money_decimal_syntax" {
    try exerciseNominal();
    try std.testing.expectError(shared.MoneyDecimalError.InvalidDecimal, shared.parseCanonicalInt64("-0"));
}

test "critical branch: money_overflow" {
    try exerciseNominal();
    try std.testing.expectError(shared.MoneyDecimalError.Overflow, shared.parseCanonicalInt64("9223372036854775808"));
}

test "critical branch: money_currency_mismatch" {
    try exerciseNominal();
    const usd = try shared.Currency.parse("USD");
    const eur = try shared.Currency.parse("EUR");
    try std.testing.expectError(shared.MoneyArithmeticError.CurrencyMismatch, (shared.Money{ .currency = usd, .minor_units = 1 }).add(.{ .currency = eur, .minor_units = 1 }));
}

test "critical branch: money_add_overflow" {
    try exerciseNominal();
    const usd = try shared.Currency.parse("USD");
    try std.testing.expectError(shared.MoneyArithmeticError.Overflow, (shared.Money{ .currency = usd, .minor_units = std.math.maxInt(i64) }).add(.{ .currency = usd, .minor_units = 1 }));
}

test "critical branch: money_sub_overflow" {
    try exerciseNominal();
    const usd = try shared.Currency.parse("USD");
    try std.testing.expectError(shared.MoneyArithmeticError.Overflow, (shared.Money{ .currency = usd, .minor_units = std.math.minInt(i64) }).sub(.{ .currency = usd, .minor_units = 1 }));
}

test "critical branch: local_date_shape" {
    try exerciseNominal();
    try std.testing.expectError(shared.LocalDateParseError.InvalidShape, shared.LocalDate.parse("2024-2-9"));
}

test "critical branch: local_date_invalid" {
    try exerciseNominal();
    try std.testing.expectError(shared.LocalDateParseError.InvalidDate, shared.LocalDate.parse("1900-02-29"));
}

test "critical branch: utc_instant_shape" {
    try exerciseNominal();
    try std.testing.expectError(shared.UtcInstantParseError.InvalidShape, shared.UtcInstant.parse("2024-01-01T00:00:00Z"));
}

test "critical branch: utc_instant_invalid_date" {
    try exerciseNominal();
    try std.testing.expectError(shared.UtcInstantParseError.InvalidDate, shared.UtcInstant.parse("2024-02-30T00:00:00.000Z"));
}

test "critical branch: utc_instant_invalid_clock" {
    try exerciseNominal();
    try std.testing.expectError(shared.UtcInstantParseError.InvalidClock, shared.UtcInstant.parse("2024-01-01T24:00:00.000Z"));
}

test "critical branch: digest_prefix" {
    try exerciseNominal();
    try std.testing.expectError(shared.DigestParseError.InvalidPrefix, shared.Sha256Digest.parse("SHA256:0000000000000000000000000000000000000000000000000000000000000000"));
}

test "critical branch: digest_length" {
    try exerciseNominal();
    try std.testing.expectError(shared.DigestParseError.InvalidLength, shared.Sha256Digest.parse("sha256:0000"));
}

test "critical branch: digest_alphabet" {
    try exerciseNominal();
    try std.testing.expectError(shared.DigestParseError.InvalidAlphabet, shared.Sha256Digest.parse("sha256:A000000000000000000000000000000000000000000000000000000000000000"));
}

test "critical branch: json_wrong_type" {
    try exerciseNominal();
    try std.testing.expectError(shared.json_http.ConversionError.WrongType, shared.json_http.parseCurrencyJson(std.testing.allocator, "42"));
}

test "critical branch: json_unknown_field" {
    try exerciseNominal();
    try std.testing.expectError(shared.json_http.ConversionError.UnknownField, shared.json_http.parseMoneyJson(std.testing.allocator, "{\"currency\":\"USD\",\"minor_units\":\"1\",\"memo\":\"synthetic\"}"));
}

test "critical branch: json_duplicate_field" {
    try exerciseNominal();
    try std.testing.expectError(shared.json_http.ConversionError.DuplicateField, shared.json_http.parseMoneyJson(std.testing.allocator, "{\"currency\":\"USD\",\"currency\":\"EUR\",\"minor_units\":\"1\"}"));
}

test "critical branch: json_missing_field" {
    try exerciseNominal();
    try std.testing.expectError(shared.json_http.ConversionError.MissingField, shared.json_http.parseMoneyJson(std.testing.allocator, "{\"currency\":\"USD\"}"));
}

test "critical branch: json_trailing_content" {
    try exerciseNominal();
    try std.testing.expectError(shared.json_http.ConversionError.TrailingContent, shared.json_http.parseMoneyJson(std.testing.allocator, "{\"currency\":\"USD\",\"minor_units\":\"1\"} false"));
}

fn exerciseNominal() !void {
    const id_text = "01890f3e-2c4a-7d5e-8abc-0123456789ab";
    const id = try shared.EntityId.parse(id_text);
    var id_output: [36]u8 = undefined;
    try std.testing.expectEqualSlices(u8, id_text, id.formatInto(&id_output));
    try std.testing.expect(id.eql(try shared.EntityId.parse(id_text)));

    const request = try shared.RequestId.parse(id_text);
    var request_output: [36]u8 = undefined;
    try std.testing.expectEqualSlices(u8, id_text, request.formatInto(&request_output));

    const zzz = try shared.Currency.parse("ZZZ");
    try std.testing.expect(zzz.eql(try shared.Currency.parse("ZZZ")));
    var currency_output: [3]u8 = undefined;
    try std.testing.expectEqualSlices(u8, "ZZZ", zzz.formatInto(&currency_output));
    const money = shared.Money{ .currency = zzz, .minor_units = try shared.parseCanonicalInt64("-9007199254740993") };
    try std.testing.expectEqual(@as(i64, -9007199254740992), (try money.add(.{ .currency = zzz, .minor_units = 1 })).minor_units);
    try std.testing.expectEqual(@as(i64, -9007199254740994), (try money.sub(.{ .currency = zzz, .minor_units = 1 })).minor_units);
    var decimal: [20]u8 = undefined;
    try std.testing.expectEqualSlices(u8, "-9007199254740993", shared.formatCanonicalInt64(money.minor_units, &decimal));

    const date = try shared.LocalDate.parse("2000-02-29");
    var date_output: [10]u8 = undefined;
    try std.testing.expectEqualSlices(u8, "2000-02-29", date.formatInto(&date_output));
    const instant = try shared.UtcInstant.parse("2024-02-29T12:34:56.999Z");
    var instant_output: [24]u8 = undefined;
    try std.testing.expectEqualSlices(u8, "2024-02-29T12:34:56.999Z", instant.formatInto(&instant_output));
    const digest_text = "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";
    const digest = try shared.Sha256Digest.parse(digest_text);
    var digest_output: [71]u8 = undefined;
    try std.testing.expectEqualSlices(u8, digest_text, digest.formatInto(&digest_output));

    const allocator = std.testing.allocator;
    _ = try shared.json_http.parseEntityIdJson(allocator, "\"01890f3e-2c4a-7d5e-8abc-0123456789ab\"");
    _ = try shared.json_http.parseRequestIdJson(allocator, "\"01890f3e-2c4a-7d5e-8abc-0123456789ab\"");
    _ = try shared.json_http.parseCurrencyJson(allocator, "\"ZZZ\"");
    _ = try shared.json_http.parseLocalDateJson(allocator, "\"2000-02-29\"");
    _ = try shared.json_http.parseUtcInstantJson(allocator, "\"2024-02-29T12:34:56.999Z\"");
    _ = try shared.json_http.parseSha256DigestJson(allocator, "\"sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855\"");
    _ = try shared.json_http.parseCanonicalInt64Json(allocator, "\"-9007199254740993\"");
    _ = try shared.json_http.parseMoneyJson(allocator, "{\"currency\":\"ZZZ\",\"minor_units\":\"-9007199254740993\"}");
    _ = try shared.json_http.parseRequestIdHeader(id_text);

    var entity_json: [38]u8 = undefined;
    _ = shared.json_http.formatEntityIdJson(id, &entity_json);
    var request_json: [38]u8 = undefined;
    _ = shared.json_http.formatRequestIdJson(request, &request_json);
    var currency_json: [5]u8 = undefined;
    _ = shared.json_http.formatCurrencyJson(zzz, &currency_json);
    var date_json: [12]u8 = undefined;
    _ = shared.json_http.formatLocalDateJson(date, &date_json);
    var instant_json: [26]u8 = undefined;
    _ = shared.json_http.formatUtcInstantJson(instant, &instant_json);
    var digest_json: [73]u8 = undefined;
    _ = shared.json_http.formatSha256DigestJson(digest, &digest_json);
    var integer_json: [22]u8 = undefined;
    _ = shared.json_http.formatCanonicalInt64Json(money.minor_units, &integer_json);
    var money_json: [64]u8 = undefined;
    _ = shared.json_http.formatMoneyJson(money, &money_json);

    try exerciseCanonicalEdges();
}

fn exerciseCanonicalEdges() !void {
    try std.testing.expectError(shared.EntityIdParseError.InvalidSyntax, shared.EntityId.parse("01890f3e_2c4a-7d5e-8abc-0123456789ab"));
    try std.testing.expectError(shared.EntityIdParseError.InvalidSyntax, shared.EntityId.parse("01890f3e-2c4a-7d5e-8abc-0123456789ag"));
    _ = try shared.EntityId.parse("01890f3e-2c4a-7d5e-9abc-0123456789ab");
    _ = try shared.EntityId.parse("01890f3e-2c4a-7d5e-aabc-0123456789ab");
    _ = try shared.EntityId.parse("01890f3e-2c4a-7d5e-babc-0123456789ab");

    for ([_][]const u8{ "", "-", "-0", "0", "+1", "01", "1x" }) |text| {
        _ = shared.parseCanonicalInt64(text) catch {};
    }
    try std.testing.expectEqual(@as(i64, std.math.minInt(i64)), try shared.parseCanonicalInt64("-9223372036854775808"));
    try std.testing.expectError(shared.MoneyDecimalError.Overflow, shared.parseCanonicalInt64("-9223372036854775809"));
    const usd = try shared.Currency.parse("USD");
    const eur = try shared.Currency.parse("EUR");
    try std.testing.expectError(shared.MoneyArithmeticError.CurrencyMismatch, (shared.Money{ .currency = usd, .minor_units = 1 }).sub(.{ .currency = eur, .minor_units = 1 }));

    for ([_][]const u8{ "0000-01-01", "2024-00-01", "2024-13-01", "2024-01-00", "2024-04-31", "1900-02-29", "2100-02-29" }) |text| {
        _ = shared.LocalDate.parse(text) catch {};
    }
    for ([_][]const u8{ "2000-02-29", "2024-01-31", "2024-04-30", "2024-06-30", "2024-09-30", "2024-11-30" }) |text| {
        _ = try shared.LocalDate.parse(text);
    }
    for ([_][]const u8{ "2024/01-01", "2024-01/01", "2024-a1-01" }) |text| {
        _ = shared.LocalDate.parse(text) catch {};
    }

    for ([_][]const u8{
        "2024-01-01T60:00:00.000Z",
        "2024-01-01T00:60:00.000Z",
        "2024-01-01T00:00:60.000Z",
        "0000-01-01T00:00:00.000Z",
    }) |text| _ = shared.UtcInstant.parse(text) catch {};
    for ([_][]const u8{
        "2024/01-01T00:00:00.000Z",
        "2024-01-01t00:00:00.000Z",
        "2024-01-01T00-00:00.000Z",
        "2024-01-01T00:00-00.000Z",
        "2024-01-01T00:00:00,000Z",
        "2024-01-01T00:00:00.000z",
        "2024-01-01T0a:00:00.000Z",
    }) |text| _ = shared.UtcInstant.parse(text) catch {};

    try std.testing.expectError(shared.DigestParseError.InvalidAlphabet, shared.Sha256Digest.parse("sha256:000000000000000000000000000000000000000000000000000000000000000g"));

    const allocator = std.testing.allocator;
    try std.testing.expectError(shared.json_http.ConversionError.InvalidValue, shared.json_http.parseCurrencyJson(allocator, "\"usd\""));
    try std.testing.expectError(shared.json_http.ConversionError.InvalidValue, shared.json_http.parseCanonicalInt64Json(allocator, "\"01\""));
    try std.testing.expectError(shared.json_http.ConversionError.InvalidValue, shared.json_http.parseMoneyJson(allocator, "{\"currency\":\"usd\",\"minor_units\":\"1\"}"));
    try std.testing.expectError(shared.json_http.ConversionError.OutOfMemory, shared.json_http.parseCurrencyJson(std.testing.failing_allocator, "\"USD\""));
    for (0..6) |fail_index| {
        var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = fail_index });
        if (shared.json_http.parseCurrencyJson(failing.allocator(), "\"USD\"")) |_| {} else |err| {
            try std.testing.expectEqual(shared.json_http.ConversionError.OutOfMemory, err);
        }
        try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
    }
}
