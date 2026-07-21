const std = @import("std");
const shared_coverage = @import("shared_coverage_probe");

pub const ParseError = error{ InvalidShape, InvalidDate };

/// Gregorian civil date in the inclusive supported year range 0001..9999.
pub const LocalDate = struct {
    year: u16,
    month: u8,
    day: u8,

    pub fn parse(text: []const u8) ParseError!LocalDate {
        if (!hasShape(text)) {
            shared_coverage.hit(.local_date_shape);
            return ParseError.InvalidShape;
        }
        const value = LocalDate{
            .year = @as(u16, digit(text[0])) * 1000 + @as(u16, digit(text[1])) * 100 + @as(u16, digit(text[2])) * 10 + digit(text[3]),
            .month = digit(text[5]) * 10 + digit(text[6]),
            .day = digit(text[8]) * 10 + digit(text[9]),
        };
        if (!value.isValid()) {
            shared_coverage.hit(.local_date_invalid);
            return ParseError.InvalidDate;
        }
        return value;
    }

    pub fn isValid(self: LocalDate) bool {
        if (self.year == 0 or self.month == 0 or self.month > 12 or self.day == 0) return false;
        return self.day <= daysInMonth(self.year, self.month);
    }

    pub fn formatInto(self: LocalDate, output: *[10]u8) []const u8 {
        return std.fmt.bufPrint(output, "{d:0>4}-{d:0>2}-{d:0>2}", .{ self.year, self.month, self.day }) catch unreachable;
    }
};

fn hasShape(text: []const u8) bool {
    if (text.len != 10 or text[4] != '-' or text[7] != '-') return false;
    for (text, 0..) |byte, index| {
        if (index == 4 or index == 7) continue;
        if (byte < '0' or byte > '9') return false;
    }
    return true;
}

fn digit(byte: u8) u8 {
    return byte - '0';
}

fn daysInMonth(year: u16, month: u8) u8 {
    return switch (month) {
        2 => if (isLeapYear(year)) 29 else 28,
        4, 6, 9, 11 => 30,
        else => 31,
    };
}

fn isLeapYear(year: u16) bool {
    return year % 4 == 0 and (year % 100 != 0 or year % 400 == 0);
}
