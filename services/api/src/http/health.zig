const envelope = @import("envelope.zig");

pub fn respond(
    allocator: @import("std").mem.Allocator,
    request_id: []const u8,
) ![]u8 {
    return envelope.successReady(allocator, request_id);
}
