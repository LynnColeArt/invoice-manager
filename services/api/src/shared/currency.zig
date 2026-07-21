const std = @import("std");
const shared_coverage = @import("shared_coverage_probe");

pub const ParseError = error{ InvalidLength, InvalidAlphabet };

/// Structural ISO-style code. Supported-currency policy belongs to a domain.
pub const Currency = struct {
    bytes: [3]u8,

    pub fn parse(text: []const u8) ParseError!Currency {
        if (text.len != 3) {
            shared_coverage.hit(.currency_length);
            return ParseError.InvalidLength;
        }
        for (text) |byte| {
            if (byte < 'A' or byte > 'Z') {
                shared_coverage.hit(.currency_alphabet);
                return ParseError.InvalidAlphabet;
            }
        }
        return .{ .bytes = text[0..3].* };
    }

    pub fn eql(left: Currency, right: Currency) bool {
        return std.mem.eql(u8, &left.bytes, &right.bytes);
    }

    pub fn formatInto(self: Currency, output: *[3]u8) []const u8 {
        output.* = self.bytes;
        return output;
    }
};
