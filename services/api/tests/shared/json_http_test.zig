const std = @import("std");
const shared = @import("shared");

test "all shared scalar values round-trip through strict JSON strings" {
    const allocator = std.testing.allocator;
    const id_text = "01890f3e-2c4a-7d5e-8abc-0123456789ab";
    const id = try shared.json_http.parseEntityIdJson(allocator, "\"01890f3e-2c4a-7d5e-8abc-0123456789ab\"");
    var id_json: [38]u8 = undefined;
    try std.testing.expectEqualSlices(u8, "\"01890f3e-2c4a-7d5e-8abc-0123456789ab\"", shared.json_http.formatEntityIdJson(id, &id_json));

    const request = try shared.json_http.parseRequestIdJson(allocator, "\"01890f3e-2c4a-7d5e-8abc-0123456789ab\"");
    var request_json: [38]u8 = undefined;
    try std.testing.expectEqualSlices(u8, "\"01890f3e-2c4a-7d5e-8abc-0123456789ab\"", shared.json_http.formatRequestIdJson(request, &request_json));
    try std.testing.expect(@TypeOf(id) != @TypeOf(request));
    const header = try shared.json_http.parseRequestIdHeader(id_text);
    var header_text: [36]u8 = undefined;
    try std.testing.expectEqualSlices(u8, id_text, header.formatInto(&header_text));

    const currency = try shared.json_http.parseCurrencyJson(allocator, "\"ZZZ\"");
    var currency_json: [5]u8 = undefined;
    try std.testing.expectEqualSlices(u8, "\"ZZZ\"", shared.json_http.formatCurrencyJson(currency, &currency_json));

    const date = try shared.json_http.parseLocalDateJson(allocator, "\"2024-02-29\"");
    var date_json: [12]u8 = undefined;
    try std.testing.expectEqualSlices(u8, "\"2024-02-29\"", shared.json_http.formatLocalDateJson(date, &date_json));

    const instant = try shared.json_http.parseUtcInstantJson(allocator, "\"2024-02-29T12:34:56.123Z\"");
    var instant_json: [26]u8 = undefined;
    try std.testing.expectEqualSlices(u8, "\"2024-02-29T12:34:56.123Z\"", shared.json_http.formatUtcInstantJson(instant, &instant_json));

    const digest_text = "sha256:0000000000000000000000000000000000000000000000000000000000000000";
    const digest = try shared.json_http.parseSha256DigestJson(allocator, "\"sha256:0000000000000000000000000000000000000000000000000000000000000000\"");
    var digest_json: [73]u8 = undefined;
    try std.testing.expectEqualSlices(u8, "\"sha256:0000000000000000000000000000000000000000000000000000000000000000\"", shared.json_http.formatSha256DigestJson(digest, &digest_json));
    _ = digest_text;
}

test "canonical i64 and Money JSON never use numeric values" {
    const allocator = std.testing.allocator;
    const value = try shared.json_http.parseCanonicalInt64Json(allocator, "\"-9223372036854775808\"");
    var integer_json: [22]u8 = undefined;
    try std.testing.expectEqualSlices(u8, "\"-9223372036854775808\"", shared.json_http.formatCanonicalInt64Json(value, &integer_json));
    try std.testing.expectError(shared.json_http.ConversionError.WrongType, shared.json_http.parseCanonicalInt64Json(allocator, "1"));

    const money = try shared.json_http.parseMoneyJson(allocator, "{\"currency\":\"ZZZ\",\"minor_units\":\"-9007199254740993\"}");
    var money_json: [64]u8 = undefined;
    try std.testing.expectEqualSlices(u8, "{\"currency\":\"ZZZ\",\"minor_units\":\"-9007199254740993\"}", shared.json_http.formatMoneyJson(money, &money_json));
    try std.testing.expectError(shared.json_http.ConversionError.WrongType, shared.json_http.parseMoneyJson(allocator, "{\"currency\":\"USD\",\"minor_units\":1}"));
}

test "Money JSON is closed complete unique and consumes all input" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(shared.json_http.ConversionError.UnknownField, shared.json_http.parseMoneyJson(allocator, "{\"currency\":\"USD\",\"minor_units\":\"1\",\"memo\":\"synthetic\"}"));
    try std.testing.expectError(shared.json_http.ConversionError.DuplicateField, shared.json_http.parseMoneyJson(allocator, "{\"currency\":\"USD\",\"currency\":\"EUR\",\"minor_units\":\"1\"}"));
    try std.testing.expectError(shared.json_http.ConversionError.MissingField, shared.json_http.parseMoneyJson(allocator, "{\"currency\":\"USD\"}"));
    try std.testing.expectError(shared.json_http.ConversionError.TrailingContent, shared.json_http.parseMoneyJson(allocator, "{\"currency\":\"USD\",\"minor_units\":\"1\"} false"));
}
