const std = @import("std");
const builtin = @import("builtin");
const fixture = @import("process_fixture.zig");
const shared = @import("shared");

const measured_requests = 100;
const one_second_ns: u64 = std.time.ns_per_s;
const get_health = "GET /api/v1/health HTTP/1.1\r\nhost: 127.0.0.1\r\nconnection: close\r\n\r\n";

fn validReadyResponse(bytes: []const u8) bool {
    if (!std.mem.startsWith(u8, bytes, "HTTP/1.1 200 OK\r\n")) return false;
    if (std.ascii.indexOfIgnoreCase(bytes, "content-type: application/json; charset=utf-8") == null) return false;
    const boundary = std.mem.indexOf(u8, bytes, "\r\n\r\n") orelse return false;
    var parsed = std.json.parseFromSlice(std.json.Value, std.testing.allocator, bytes[boundary + 4 ..], .{}) catch return false;
    defer parsed.deinit();
    if (parsed.value != .object or parsed.value.object.count() != 2) return false;
    const data = parsed.value.object.get("data") orelse return false;
    const meta = parsed.value.object.get("meta") orelse return false;
    if (data != .object or data.object.count() != 1) return false;
    const status = data.object.get("status") orelse return false;
    if (status != .string or !std.mem.eql(u8, status.string, "ready")) return false;
    if (meta != .object or meta.object.count() != 1) return false;
    const request_id = meta.object.get("request_id") orelse return false;
    if (request_id != .string) return false;
    _ = shared.RequestId.parse(request_id.string) catch return false;
    return true;
}

test "exactly 100 real ready requests satisfy the local P0 latency budget" {
    var service = try fixture.Service.start(std.testing.allocator, std.testing.io);
    defer service.stop(std.testing.io);

    for (0..10) |_| {
        const warm = try service.request(get_health);
        defer std.testing.allocator.free(warm);
        try std.testing.expect(validReadyResponse(warm));
    }

    var durations_ns: [measured_requests]u64 = undefined;
    var valid_count: usize = 0;
    var valid_within_budget: usize = 0;
    var failure_count: usize = 0;
    for (0..measured_requests) |index| {
        const before = std.Io.Clock.awake.now(std.testing.io);
        const response = service.request(get_health) catch {
            const after = std.Io.Clock.awake.now(std.testing.io);
            durations_ns[index] = @intCast(before.durationTo(after).toNanoseconds());
            failure_count += 1;
            continue;
        };
        const after = std.Io.Clock.awake.now(std.testing.io);
        defer std.testing.allocator.free(response);
        durations_ns[index] = @intCast(before.durationTo(after).toNanoseconds());
        if (!validReadyResponse(response)) {
            failure_count += 1;
            continue;
        }
        valid_count += 1;
        if (durations_ns[index] <= one_second_ns) valid_within_budget += 1;
        const remaining = measured_requests - index - 1;
        if (valid_within_budget + remaining < 99) {
            std.debug.print(
                "[wp08:performance] budget became impossible after request={d} duration_us={d}\n",
                .{ index + 1, durations_ns[index] / std.time.ns_per_us },
            );
            return error.PerformanceBudgetImpossible;
        }
    }

    std.mem.sort(u64, &durations_ns, {}, std.sort.asc(u64));
    const median_ns = (durations_ns[49] + durations_ns[50]) / 2;
    const p99_ns = durations_ns[98];
    std.debug.print(
        "[wp08:performance] mode={s} requests=100 min_us={d} median_us={d} p99_us={d} max_us={d} failures={d}\n",
        .{
            @tagName(builtin.mode),
            durations_ns[0] / std.time.ns_per_us,
            median_ns / std.time.ns_per_us,
            p99_ns / std.time.ns_per_us,
            durations_ns[99] / std.time.ns_per_us,
            failure_count,
        },
    );
    try std.testing.expectEqual(@as(usize, measured_requests), valid_count);
    try std.testing.expectEqual(@as(usize, 0), failure_count);
    try std.testing.expect(valid_within_budget >= 99);
}
