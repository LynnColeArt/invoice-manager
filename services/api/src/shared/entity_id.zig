const std = @import("std");
const shared_coverage = @import("shared_coverage_probe");

pub const ParseError = error{
    InvalidLength,
    InvalidSyntax,
    InvalidVersion,
    InvalidVariant,
};

/// Opaque UUIDv7 identity. The bytes deliberately expose no ordering API.
pub const EntityId = struct {
    bytes: [16]u8,

    pub fn parse(text: []const u8) ParseError!EntityId {
        if (text.len != 36) {
            shared_coverage.hit(.entity_id_length);
            return ParseError.InvalidLength;
        }
        const hyphens = [_]usize{ 8, 13, 18, 23 };
        for (hyphens) |index| {
            if (text[index] != '-') {
                shared_coverage.hit(.entity_id_syntax);
                return ParseError.InvalidSyntax;
            }
        }

        var bytes: [16]u8 = undefined;
        var text_index: usize = 0;
        var byte_index: usize = 0;
        while (byte_index < bytes.len) : (byte_index += 1) {
            while (text_index < text.len and text[text_index] == '-') text_index += 1;
            const high = hexNibble(text[text_index]) orelse {
                shared_coverage.hit(.entity_id_syntax);
                return ParseError.InvalidSyntax;
            };
            const low = hexNibble(text[text_index + 1]) orelse {
                shared_coverage.hit(.entity_id_syntax);
                return ParseError.InvalidSyntax;
            };
            bytes[byte_index] = high << 4 | low;
            text_index += 2;
        }
        if (bytes[6] >> 4 != 7) {
            shared_coverage.hit(.entity_id_version);
            return ParseError.InvalidVersion;
        }
        if (bytes[8] & 0xc0 != 0x80) {
            shared_coverage.hit(.entity_id_variant);
            return ParseError.InvalidVariant;
        }
        return .{ .bytes = bytes };
    }

    pub fn eql(left: EntityId, right: EntityId) bool {
        return std.mem.eql(u8, &left.bytes, &right.bytes);
    }

    pub fn formatInto(self: EntityId, output: *[36]u8) []const u8 {
        var output_index: usize = 0;
        for (self.bytes, 0..) |byte, byte_index| {
            if (byte_index == 4 or byte_index == 6 or byte_index == 8 or byte_index == 10) {
                output[output_index] = '-';
                output_index += 1;
            }
            output[output_index] = hexDigit(byte >> 4);
            output[output_index + 1] = hexDigit(byte & 0x0f);
            output_index += 2;
        }
        return output;
    }
};

fn hexNibble(byte: u8) ?u8 {
    return switch (byte) {
        '0'...'9' => byte - '0',
        'a'...'f' => byte - 'a' + 10,
        else => null,
    };
}

fn hexDigit(nibble: u8) u8 {
    return if (nibble < 10) '0' + nibble else 'a' + nibble - 10;
}
