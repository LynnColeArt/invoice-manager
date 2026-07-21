const std = @import("std");
const shared = @import("shared");

test "EntityId accepts all RFC variant nibbles and round-trips" {
    const values = [_][]const u8{
        "01890f3e-2c4a-7d5e-8abc-0123456789ab",
        "01890f3e-2c4a-7d5e-9abc-0123456789ab",
        "01890f3e-2c4a-7d5e-aabc-0123456789ab",
        "01890f3e-2c4a-7d5e-babc-0123456789ab",
    };
    for (values) |text| {
        const value = try shared.EntityId.parse(text);
        var output: [36]u8 = undefined;
        try std.testing.expectEqualSlices(u8, text, value.formatInto(&output));
        try std.testing.expect(value.eql(try shared.EntityId.parse(output[0..])));
    }
}

test "EntityId rejects noncanonical forms by stable category" {
    try std.testing.expectError(shared.EntityIdParseError.InvalidLength, shared.EntityId.parse("01890f3e-2c4a-7d5e-8abc-0123456789a"));
    try std.testing.expectError(shared.EntityIdParseError.InvalidSyntax, shared.EntityId.parse("01890F3E-2C4A-7D5E-8ABC-0123456789AB"));
    try std.testing.expectError(shared.EntityIdParseError.InvalidSyntax, shared.EntityId.parse("01890f3e_2c4a-7d5e-8abc-0123456789ab"));
    try std.testing.expectError(shared.EntityIdParseError.InvalidVersion, shared.EntityId.parse("01890f3e-2c4a-6d5e-8abc-0123456789ab"));
    try std.testing.expectError(shared.EntityIdParseError.InvalidVariant, shared.EntityId.parse("01890f3e-2c4a-7d5e-7abc-0123456789ab"));
}

test "EntityId equality compares canonical bytes" {
    const left = try shared.EntityId.parse("00000000-0000-7000-8000-000000000000");
    const same = try shared.EntityId.parse("00000000-0000-7000-8000-000000000000");
    const other = try shared.EntityId.parse("00000000-0000-7000-8000-000000000001");
    try std.testing.expect(left.eql(same));
    try std.testing.expect(!left.eql(other));
}
