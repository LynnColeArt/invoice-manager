const entity = @import("entity_id.zig");

pub const ParseError = entity.ParseError;

/// Request correlation identity; wire-compatible but not type-interchangeable.
pub const RequestId = struct {
    inner: entity.EntityId,

    pub fn parse(text: []const u8) ParseError!RequestId {
        return .{ .inner = try entity.EntityId.parse(text) };
    }

    pub fn formatInto(self: RequestId, output: *[36]u8) []const u8 {
        return self.inner.formatInto(output);
    }
};
