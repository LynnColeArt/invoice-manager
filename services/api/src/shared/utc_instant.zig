const std = @import("std");
const date_module = @import("local_date.zig");
const shared_coverage = @import("shared_coverage_probe");

pub const ParseError = error{ InvalidShape, InvalidDate, InvalidClock };

pub const UtcInstant = struct {
    date: date_module.LocalDate,
    hour: u8,
    minute: u8,
    second: u8,
    millisecond: u16,

    pub fn parse(text: []const u8) ParseError!UtcInstant {
        if (!hasShape(text)) {
            shared_coverage.hit(.utc_instant_shape);
            return ParseError.InvalidShape;
        }
        const date = date_module.LocalDate.parse(text[0..10]) catch {
            shared_coverage.hit(.utc_instant_invalid_date);
            return ParseError.InvalidDate;
        };
        const value = UtcInstant{
            .date = date,
            .hour = digit(text[11]) * 10 + digit(text[12]),
            .minute = digit(text[14]) * 10 + digit(text[15]),
            .second = digit(text[17]) * 10 + digit(text[18]),
            .millisecond = @as(u16, digit(text[20])) * 100 + @as(u16, digit(text[21])) * 10 + digit(text[22]),
        };
        if (value.hour > 23 or value.minute > 59 or value.second > 59) {
            shared_coverage.hit(.utc_instant_invalid_clock);
            return ParseError.InvalidClock;
        }
        return value;
    }

    pub fn formatInto(self: UtcInstant, output: *[24]u8) []const u8 {
        return std.fmt.bufPrint(
            output,
            "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}.{d:0>3}Z",
            .{ self.date.year, self.date.month, self.date.day, self.hour, self.minute, self.second, self.millisecond },
        ) catch unreachable;
    }
};

fn hasShape(text: []const u8) bool {
    if (text.len != 24 or text[4] != '-' or text[7] != '-' or text[10] != 'T' or
        text[13] != ':' or text[16] != ':' or text[19] != '.' or text[23] != 'Z') return false;
    for (text, 0..) |byte, index| {
        switch (index) {
            4, 7, 10, 13, 16, 19, 23 => continue,
            else => if (byte < '0' or byte > '9') return false,
        }
    }
    return true;
}

fn digit(byte: u8) u8 {
    return byte - '0';
}
