const std = @import("std");

pub const CriticalBranch = enum(u8) {
    entity_id_length,
    entity_id_syntax,
    entity_id_version,
    entity_id_variant,
    currency_length,
    currency_alphabet,
    money_decimal_syntax,
    money_overflow,
    money_currency_mismatch,
    money_add_overflow,
    money_sub_overflow,
    local_date_shape,
    local_date_invalid,
    utc_instant_shape,
    utc_instant_invalid_date,
    utc_instant_invalid_clock,
    digest_prefix,
    digest_length,
    digest_alphabet,
    json_wrong_type,
    json_unknown_field,
    json_duplicate_field,
    json_missing_field,
    json_trailing_content,
};

var hit_bits: std.atomic.Value(u64) = .init(0);

pub fn hit(comptime branch: CriticalBranch) void {
    @disableInstrumentation();
    _ = hit_bits.fetchOr(@as(u64, 1) << @intFromEnum(branch), .monotonic);
}

export fn invoice_manager_shared_coverage_reset() void {
    @disableInstrumentation();
    hit_bits.store(0, .monotonic);
}

export fn invoice_manager_shared_coverage_hit_bits() u64 {
    @disableInstrumentation();
    return hit_bits.load(.monotonic);
}

export fn invoice_manager_shared_coverage_required_bits() u64 {
    @disableInstrumentation();
    return (@as(u64, 1) << @typeInfo(CriticalBranch).@"enum".fields.len) - 1;
}
