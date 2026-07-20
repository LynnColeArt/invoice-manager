const std = @import("std");
const shovelerdb = @import("shovelerdb_adapter");

fn temporaryDatabasePath(
    allocator: std.mem.Allocator,
    tmp: *const std.testing.TmpDir,
) ![:0]u8 {
    return std.fmt.allocPrintSentinel(
        allocator,
        ".zig-cache/tmp/{s}/wp04-probe.shovel",
        .{tmp.sub_path},
        0,
    );
}

fn expectMutation(result: shovelerdb.OwnedResult, expected: u64) !void {
    switch (result) {
        .mutation_count => |count| try std.testing.expectEqual(expected, count),
        else => return error.ExpectedMutationCount,
    }
}

fn expectProbeRows(result: *const shovelerdb.OwnedResult) !void {
    const rows = switch (result.*) {
        .rows => |rows| rows,
        else => return error.ExpectedRows,
    };
    try std.testing.expectEqual(@as(usize, 6), rows.column_names.len);
    try std.testing.expectEqualStrings("literal", rows.column_names[0]);
    try std.testing.expectEqualStrings("id", rows.column_names[1]);
    try std.testing.expectEqualStrings("score", rows.column_names[2]);
    try std.testing.expectEqualStrings("active", rows.column_names[3]);
    try std.testing.expectEqualStrings("body", rows.column_names[4]);
    try std.testing.expectEqualStrings("embedding", rows.column_names[5]);
    try std.testing.expectEqual(@as(usize, 2), rows.rows.len);

    try std.testing.expect(rows.rows[0].values[0] == .null_value);
    try std.testing.expectEqual(@as(i64, 1), rows.rows[0].values[1].integer);
    try std.testing.expectEqual(@as(f64, 1.5), rows.rows[0].values[2].float);
    try std.testing.expect(rows.rows[0].values[3].boolean);
    try std.testing.expectEqualStrings("O'Reilly", rows.rows[0].values[4].text);
    try std.testing.expectEqualSlices(
        f32,
        &.{ 0.25, 0.75 },
        rows.rows[0].values[5].vector_f32,
    );

    try std.testing.expect(rows.rows[1].values[0] == .null_value);
    try std.testing.expectEqual(@as(i64, 2), rows.rows[1].values[1].integer);
    try std.testing.expectEqual(@as(f64, -2.25), rows.rows[1].values[2].float);
    try std.testing.expect(!rows.rows[1].values[3].boolean);
    try std.testing.expectEqualStrings("a'; DROP TABLE wp04_probe; --", rows.rows[1].values[4].text);
    try std.testing.expectEqualSlices(
        f32,
        &.{ -1.0, 3.5 },
        rows.rows[1].values[5].vector_f32,
    );
}

fn concurrentSelect(adapter: *shovelerdb.Adapter, failures: *std.atomic.Value(u32)) void {
    var result = adapter.execute(
        std.heap.smp_allocator,
        "SELECT NULL, id, score, active, body, embedding FROM wp04_probe;",
    ) catch {
        _ = failures.fetchAdd(1, .monotonic);
        return;
    };
    defer result.deinit(std.heap.smp_allocator);
    if (result != .rows) _ = failures.fetchAdd(1, .monotonic);
}

test "real ABI copies values then checkpoints closes and reopens" {
    const allocator = std.testing.allocator;
    try std.testing.expect(shovelerdb.abiVersion().isExpected());

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try temporaryDatabasePath(allocator, &tmp);
    defer allocator.free(path);

    var adapter = try shovelerdb.Adapter.open(allocator, path);
    defer adapter.deinit();

    var created = try adapter.execute(
        allocator,
        "CREATE TABLE wp04_probe (id INTEGER, score FLOAT, active BOOLEAN, body TEXT, embedding VECTOR(2));",
    );
    created.deinit(allocator);

    try adapter.begin();
    var first = try adapter.executeText(
        allocator,
        "INSERT INTO wp04_probe VALUES (1, 1.5, TRUE, ",
        "O'Reilly",
        ", [0.25, 0.75]);",
    );
    try expectMutation(first, 1);
    first.deinit(allocator);

    var second = try adapter.executeText(
        allocator,
        "INSERT INTO wp04_probe VALUES (2, -2.25, FALSE, ",
        "a'; DROP TABLE wp04_probe; --",
        ", [-1.0, 3.5]);",
    );
    try expectMutation(second, 1);
    second.deinit(allocator);
    try adapter.commit();

    var selected = try adapter.execute(
        allocator,
        "SELECT NULL, id, score, active, body, embedding FROM wp04_probe;",
    );
    // The adapter has released the C result before returning these owned bytes.
    try expectProbeRows(&selected);
    selected.deinit(allocator);

    // The exact public SQL path at this pin exposes text and vector literals,
    // but no SQL BLOB literal. The adapter still copies ABI blob views when a
    // result supplies one; this black-box probe does not import engine internals.
    try adapter.checkpoint();
    adapter.close();
    try std.testing.expectError(
        error.Closed,
        adapter.execute(allocator, "SELECT id FROM wp04_probe;"),
    );
    adapter.close();

    adapter = try shovelerdb.Adapter.open(allocator, path);
    var reopened = try adapter.execute(
        allocator,
        "SELECT NULL, id, score, active, body, embedding FROM wp04_probe;",
    );
    try expectProbeRows(&reopened);
    reopened.deinit(allocator);

    try adapter.begin();
    var rollback_insert = try adapter.executeText(
        allocator,
        "INSERT INTO wp04_probe VALUES (3, 0.0, TRUE, ",
        "rollback-sentinel",
        ", [0.0, 0.0]);",
    );
    rollback_insert.deinit(allocator);
    try adapter.rollback();

    var after_rollback = try adapter.execute(
        allocator,
        "SELECT NULL, id, score, active, body, embedding FROM wp04_probe;",
    );
    try expectProbeRows(&after_rollback);
    after_rollback.deinit(allocator);

    var failures = std.atomic.Value(u32).init(0);
    const thread_one = try std.Thread.spawn(.{}, concurrentSelect, .{ &adapter, &failures });
    const thread_two = try std.Thread.spawn(.{}, concurrentSelect, .{ &adapter, &failures });
    thread_one.join();
    thread_two.join();
    try std.testing.expectEqual(@as(u32, 0), failures.load(.monotonic));
}

test "execution failures stay categorized and allocation cleanup preserves the handle" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try temporaryDatabasePath(allocator, &tmp);
    defer allocator.free(path);

    var adapter = try shovelerdb.Adapter.open(allocator, path);
    defer adapter.deinit();
    var created = try adapter.execute(allocator, "CREATE TABLE wp04_probe (body TEXT);");
    created.deinit(allocator);

    try std.testing.expectError(error.Parse, adapter.execute(
        allocator,
        "SELECT FROM sql-sentinel-DO-NOT-LEAK;",
    ));
    try std.testing.expectEqual(
        shovelerdb.ErrorCategory.parse,
        shovelerdb.category(error.Parse),
    );

    const diagnostic = try shovelerdb.testing.copyLastDiagnostic(&adapter, allocator);
    defer allocator.free(diagnostic);
    try std.testing.expect(std.mem.indexOf(u8, diagnostic, "sql-sentinel") == null);
    try std.testing.expect(std.mem.indexOf(u8, diagnostic, "wp04-probe.shovel") == null);

    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    try std.testing.expectError(
        error.OutOfMemory,
        adapter.execute(failing.allocator(), "SELECT body FROM wp04_probe;"),
    );
    try std.testing.expect(failing.has_induced_failure);

    var usable_after_failure = try adapter.execute(allocator, "SELECT body FROM wp04_probe;");
    defer usable_after_failure.deinit(allocator);
    switch (usable_after_failure) {
        .rows => |rows| try std.testing.expectEqual(@as(usize, 0), rows.rows.len),
        else => return error.ExpectedRows,
    }
}

test "Unicode newline and backslash text round trips byte for byte" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try temporaryDatabasePath(allocator, &tmp);
    defer allocator.free(path);

    var adapter = try shovelerdb.Adapter.open(allocator, path);
    defer adapter.deinit();
    var created = try adapter.execute(allocator, "CREATE TABLE wp04_probe (body TEXT);");
    created.deinit(allocator);

    const expected = "naïve 猫\nslash\\tab\tcarriage\r/* */; --";
    try adapter.begin();
    var inserted = try adapter.executeText(
        allocator,
        "INSERT INTO wp04_probe VALUES (",
        expected,
        ");",
    );
    inserted.deinit(allocator);
    try adapter.commit();

    var selected = try adapter.execute(allocator, "SELECT body FROM wp04_probe;");
    defer selected.deinit(allocator);
    switch (selected) {
        .rows => |rows| {
            try std.testing.expectEqual(@as(usize, 1), rows.rows.len);
            try std.testing.expectEqualStrings(expected, rows.rows[0].values[0].text);
        },
        else => return error.ExpectedRows,
    }
}
