const std = @import("std");
const shared_coverage = @import("shared_coverage_probe");

pub const ParseError = error{ InvalidPrefix, InvalidLength, InvalidAlphabet };

pub const Sha256Digest = struct {
    bytes: [32]u8,

    pub fn parse(text: []const u8) ParseError!Sha256Digest {
        if (text.len != 71) {
            shared_coverage.hit(.digest_length);
            return ParseError.InvalidLength;
        }
        if (!std.mem.eql(u8, text[0..7], "sha256:")) {
            shared_coverage.hit(.digest_prefix);
            return ParseError.InvalidPrefix;
        }
        var bytes: [32]u8 = undefined;
        for (&bytes, 0..) |*byte, index| {
            const high = hexNibble(text[7 + index * 2]) orelse {
                shared_coverage.hit(.digest_alphabet);
                return ParseError.InvalidAlphabet;
            };
            const low = hexNibble(text[8 + index * 2]) orelse {
                shared_coverage.hit(.digest_alphabet);
                return ParseError.InvalidAlphabet;
            };
            byte.* = high << 4 | low;
        }
        return .{ .bytes = bytes };
    }

    pub fn formatInto(self: Sha256Digest, output: *[71]u8) []const u8 {
        @memcpy(output[0..7], "sha256:");
        for (self.bytes, 0..) |byte, index| {
            output[7 + index * 2] = hexDigit(byte >> 4);
            output[8 + index * 2] = hexDigit(byte & 0x0f);
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
