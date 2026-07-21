pub const Kind = enum {
    malformed_request,
    not_found,
    method_not_allowed,
    not_ready,
    internal,
    protected_route,
};

pub const PublicError = struct {
    status: u16,
    reason: []const u8,
    code: []const u8,
    message: []const u8,
};

pub fn map(kind: Kind) PublicError {
    return switch (kind) {
        .malformed_request => .{ .status = 400, .reason = "Bad Request", .code = "malformed_request", .message = "The request is malformed." },
        .not_found => .{ .status = 404, .reason = "Not Found", .code = "route_not_found", .message = "The requested route does not exist." },
        .method_not_allowed => .{ .status = 405, .reason = "Method Not Allowed", .code = "method_not_allowed", .message = "The request method is not supported." },
        .not_ready => .{ .status = 503, .reason = "Service Unavailable", .code = "service_not_ready", .message = "The service is not ready." },
        .internal => .{ .status = 500, .reason = "Internal Server Error", .code = "internal_error", .message = "An internal error occurred." },
        .protected_route => .{ .status = 404, .reason = "Not Found", .code = "route_not_found", .message = "The requested route does not exist." },
    };
}
