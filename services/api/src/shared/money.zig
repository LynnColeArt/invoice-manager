const std = @import("std");
const currency_module = @import("currency.zig");
const shared_coverage = @import("shared_coverage_probe");

pub const Currency = currency_module.Currency;

pub const DecimalError = error{ InvalidDecimal, Overflow };
pub const ArithmeticError = error{ CurrencyMismatch, Overflow };

pub const Money = struct {
    currency: Currency,
    minor_units: i64,

    pub fn add(left: Money, right: Money) ArithmeticError!Money {
        if (!Currency.eql(left.currency, right.currency)) {
            shared_coverage.hit(.money_currency_mismatch);
            return ArithmeticError.CurrencyMismatch;
        }
        const sum = std.math.add(i64, left.minor_units, right.minor_units) catch {
            shared_coverage.hit(.money_add_overflow);
            return ArithmeticError.Overflow;
        };
        return .{ .currency = left.currency, .minor_units = sum };
    }

    pub fn sub(left: Money, right: Money) ArithmeticError!Money {
        if (!Currency.eql(left.currency, right.currency)) {
            shared_coverage.hit(.money_currency_mismatch);
            return ArithmeticError.CurrencyMismatch;
        }
        const difference = std.math.sub(i64, left.minor_units, right.minor_units) catch {
            shared_coverage.hit(.money_sub_overflow);
            return ArithmeticError.Overflow;
        };
        return .{ .currency = left.currency, .minor_units = difference };
    }
};

pub fn parseCanonicalInt64(text: []const u8) DecimalError!i64 {
    if (!hasCanonicalDecimalShape(text)) {
        shared_coverage.hit(.money_decimal_syntax);
        return DecimalError.InvalidDecimal;
    }
    return std.fmt.parseInt(i64, text, 10) catch {
        shared_coverage.hit(.money_overflow);
        return DecimalError.Overflow;
    };
}

pub fn formatCanonicalInt64(value: i64, output: *[20]u8) []const u8 {
    return std.fmt.bufPrint(output, "{d}", .{value}) catch unreachable;
}

fn hasCanonicalDecimalShape(text: []const u8) bool {
    if (text.len == 0) return false;
    var index: usize = 0;
    if (text[0] == '-') {
        if (text.len == 1 or text[1] == '0') return false;
        index = 1;
    } else if (text[0] == '0') {
        return text.len == 1;
    } else if (text[0] < '1' or text[0] > '9') {
        return false;
    }
    while (index < text.len) : (index += 1) {
        if (text[index] < '0' or text[index] > '9') return false;
    }
    return true;
}
