const std = @import("std");
const builtin = @import("builtin");

const c = @cImport({
    @cInclude("shovelerdb.h");
});

comptime {
    if (c.SHOVELERDB_ABI_VERSION_MAJOR != 0 or
        c.SHOVELERDB_ABI_VERSION_MINOR != 1 or
        c.SHOVELERDB_ABI_VERSION_PATCH != 0)
    {
        @compileError("WP04 requires ShovelerDB header ABI 0.1.0");
    }
}

pub const ErrorCategory = enum {
    invalid_argument,
    closed,
    allocation,
    parse,
    object,
    transaction,
    type_mismatch,
    vector,
    persistence,
    io,
    unsupported,
    internal,
    abi_mismatch,
    embedded_nul,
    binding_arity_mismatch,
};

pub const Version = struct {
    major: u32,
    minor: u32,
    patch: u32,

    pub fn isExpected(self: Version) bool {
        return self.major == 0 and self.minor == 1 and self.patch == 0;
    }
};

pub const OwnedValue = union(enum) {
    null_value,
    integer: i64,
    float: f64,
    boolean: bool,
    text: []u8,
    blob: []u8,
    vector_f32: []f32,

    pub fn deinit(self: *OwnedValue, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .text => |bytes| allocator.free(bytes),
            .blob => |bytes| allocator.free(bytes),
            .vector_f32 => |values| allocator.free(values),
            else => {},
        }
        self.* = .null_value;
    }
};

pub const OwnedRow = struct {
    values: []OwnedValue,

    pub fn deinit(self: *OwnedRow, allocator: std.mem.Allocator) void {
        for (self.values) |*value| value.deinit(allocator);
        allocator.free(self.values);
        self.* = undefined;
    }
};

pub const OwnedRows = struct {
    column_names: [][]u8,
    rows: []OwnedRow,

    pub fn deinit(self: *OwnedRows, allocator: std.mem.Allocator) void {
        for (self.column_names) |name| allocator.free(name);
        allocator.free(self.column_names);
        for (self.rows) |*row| row.deinit(allocator);
        allocator.free(self.rows);
        self.* = undefined;
    }
};

pub const OwnedResult = union(enum) {
    empty,
    mutation_count: u64,
    rows: OwnedRows,

    pub fn deinit(self: *OwnedResult, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .rows => |*rows| rows.deinit(allocator),
            else => {},
        }
        self.* = .empty;
    }
};

/// One adapter owns one handle. Do not bit-copy an initialized adapter.
/// All calls that share the handle are serialized by `mutex`.
pub const Adapter = struct {
    allocator: std.mem.Allocator,
    handle: ?*c.shovelerdb_database,
    mutex: std.atomic.Mutex = .unlocked,

    pub fn open(allocator: std.mem.Allocator, path: []const u8) !Adapter {
        if (std.mem.indexOfScalar(u8, path, 0) != null) return error.EmbeddedNul;
        if (!abiVersion().isExpected()) return error.AbiMismatch;

        const path_z = try allocator.dupeZ(u8, path);
        defer allocator.free(path_z);

        var handle: ?*c.shovelerdb_database = null;
        const status = c.shovelerdb_open_or_create(path_z.ptr, &handle);
        if (status != c.SHOVELERDB_STATUS_OK) return statusError(status);

        return .{
            .allocator = allocator,
            .handle = handle orelse return error.Internal,
        };
    }

    pub fn close(self: *Adapter) void {
        lockMutex(&self.mutex);
        defer self.mutex.unlock();

        if (self.handle) |handle| {
            c.shovelerdb_close(handle);
            self.handle = null;
        }
    }

    pub fn deinit(self: *Adapter) void {
        self.close();
    }

    pub fn checkpoint(self: *Adapter) !void {
        lockMutex(&self.mutex);
        defer self.mutex.unlock();

        const handle = self.handle orelse return error.Closed;
        const status = c.shovelerdb_checkpoint(handle);
        if (status != c.SHOVELERDB_STATUS_OK) return statusError(status);
    }

    /// Executes reviewed compile-time SQL. Dynamic text must use `executeText`.
    pub fn execute(
        self: *Adapter,
        allocator: std.mem.Allocator,
        comptime sql: [:0]const u8,
    ) !OwnedResult {
        return self.executeOwned(allocator, sql);
    }

    /// Executes a statement whose only dynamic SQL bytes are one encoded text
    /// literal between reviewed compile-time prefix and suffix fragments.
    pub fn executeText(
        self: *Adapter,
        allocator: std.mem.Allocator,
        comptime prefix: []const u8,
        text: []const u8,
        comptime suffix: []const u8,
    ) !OwnedResult {
        return self.executeBound(allocator, &.{ prefix, suffix }, &.{text});
    }

    /// Interleaves compile-time-reviewed SQL fragments with independently
    /// encoded runtime text values. No runtime fragment or identifier enters
    /// this boundary.
    pub fn executeBound(
        self: *Adapter,
        allocator: std.mem.Allocator,
        comptime fragments: []const []const u8,
        values: []const []const u8,
    ) !OwnedResult {
        if (fragments.len == 0 or fragments.len - 1 != values.len) {
            return error.BindingArityMismatch;
        }
        inline for (fragments) |fragment| {
            if (std.mem.indexOfScalar(u8, fragment, 0) != null) return error.EmbeddedNul;
        }
        for (values) |value| {
            if (std.mem.indexOfScalar(u8, value, 0) != null) return error.EmbeddedNul;
        }

        var statement: std.ArrayList(u8) = .empty;
        defer statement.deinit(allocator);
        inline for (fragments, 0..) |fragment, index| {
            try statement.appendSlice(allocator, fragment);
            if (index < values.len) {
                const literal = try encodeTextLiteral(allocator, values[index]);
                defer allocator.free(literal);
                try statement.appendSlice(allocator, literal);
            }
        }

        const sql = try allocator.dupeZ(u8, statement.items);
        defer allocator.free(sql);
        return self.executeOwned(allocator, sql);
    }

    /// Executes one exact runtime statement for a separately constrained
    /// startup capability. Bytes are only copied into sentinel form: no trim,
    /// newline conversion, splitting, or identifier construction occurs here.
    pub fn executeScript(
        self: *Adapter,
        allocator: std.mem.Allocator,
        script: []const u8,
    ) !OwnedResult {
        if (std.mem.indexOfScalar(u8, script, 0) != null) return error.EmbeddedNul;
        const sql = try allocator.dupeZ(u8, script);
        defer allocator.free(sql);
        return self.executeOwned(allocator, sql);
    }

    pub fn begin(self: *Adapter) !void {
        var result = try self.execute(self.allocator, "BEGIN;");
        result.deinit(self.allocator);
    }

    pub fn commit(self: *Adapter) !void {
        var result = try self.execute(self.allocator, "COMMIT;");
        result.deinit(self.allocator);
    }

    pub fn rollback(self: *Adapter) !void {
        var result = try self.execute(self.allocator, "ROLLBACK;");
        result.deinit(self.allocator);
    }

    fn executeOwned(
        self: *Adapter,
        allocator: std.mem.Allocator,
        sql: [:0]const u8,
    ) !OwnedResult {
        lockMutex(&self.mutex);
        defer self.mutex.unlock();

        const handle = self.handle orelse return error.Closed;
        var raw_result: ?*c.shovelerdb_result = null;
        const status = c.shovelerdb_execute(handle, sql.ptr, &raw_result);
        if (status != c.SHOVELERDB_STATUS_OK) {
            if (raw_result) |result| c.shovelerdb_result_release(result);
            return statusError(status);
        }

        const result = raw_result orelse return error.Internal;
        defer c.shovelerdb_result_release(result);
        return copyResult(allocator, result);
    }
};

pub fn abiVersion() Version {
    return .{
        .major = c.shovelerdb_abi_version_major(),
        .minor = c.shovelerdb_abi_version_minor(),
        .patch = c.shovelerdb_abi_version_patch(),
    };
}

pub fn encodeTextLiteral(allocator: std.mem.Allocator, input: []const u8) ![:0]u8 {
    if (std.mem.indexOfScalar(u8, input, 0) != null) return error.EmbeddedNul;

    var quote_count: usize = 0;
    for (input) |byte| {
        if (byte == '\'') quote_count += 1;
    }

    const encoded = try allocator.allocSentinel(u8, input.len + quote_count + 2, 0);
    var out: usize = 0;
    encoded[out] = '\'';
    out += 1;
    for (input) |byte| {
        encoded[out] = byte;
        out += 1;
        if (byte == '\'') {
            encoded[out] = '\'';
            out += 1;
        }
    }
    encoded[out] = '\'';
    return encoded;
}

pub fn category(err: anyerror) ErrorCategory {
    return switch (err) {
        error.InvalidArgument => .invalid_argument,
        error.Closed => .closed,
        error.OutOfMemory, error.AllocationFailed => .allocation,
        error.Parse => .parse,
        error.Object => .object,
        error.Transaction => .transaction,
        error.TypeMismatch => .type_mismatch,
        error.Vector => .vector,
        error.Persistence => .persistence,
        error.Io => .io,
        error.Unsupported => .unsupported,
        error.AbiMismatch => .abi_mismatch,
        error.EmbeddedNul => .embedded_nul,
        error.BindingArityMismatch => .binding_arity_mismatch,
        else => .internal,
    };
}

fn statusError(status: c.shovelerdb_status) anyerror {
    return switch (status) {
        c.SHOVELERDB_STATUS_INVALID_ARGUMENT => error.InvalidArgument,
        c.SHOVELERDB_STATUS_INVALID_HANDLE => error.Closed,
        c.SHOVELERDB_STATUS_ALLOCATION_FAILED => error.AllocationFailed,
        c.SHOVELERDB_STATUS_PARSE_ERROR => error.Parse,
        c.SHOVELERDB_STATUS_OBJECT_ERROR => error.Object,
        c.SHOVELERDB_STATUS_TRANSACTION_ERROR => error.Transaction,
        c.SHOVELERDB_STATUS_TYPE_ERROR => error.TypeMismatch,
        c.SHOVELERDB_STATUS_VECTOR_ERROR => error.Vector,
        c.SHOVELERDB_STATUS_PERSISTENCE_ERROR => error.Persistence,
        c.SHOVELERDB_STATUS_IO_ERROR => error.Io,
        c.SHOVELERDB_STATUS_UNSUPPORTED => error.Unsupported,
        else => error.Internal,
    };
}

fn copyResult(allocator: std.mem.Allocator, result: *c.shovelerdb_result) !OwnedResult {
    return switch (c.shovelerdb_result_kind_of(result)) {
        c.SHOVELERDB_RESULT_EMPTY => .empty,
        c.SHOVELERDB_RESULT_MUTATION_COUNT => .{
            .mutation_count = c.shovelerdb_result_mutation_count(result),
        },
        c.SHOVELERDB_RESULT_ROWS => .{
            .rows = try copyRows(allocator, result),
        },
        else => error.Internal,
    };
}

fn copyRows(allocator: std.mem.Allocator, result: *c.shovelerdb_result) !OwnedRows {
    const column_count = c.shovelerdb_result_column_count(result);
    const column_names = try allocator.alloc([]u8, column_count);
    var names_initialized: usize = 0;
    errdefer {
        for (column_names[0..names_initialized]) |name| allocator.free(name);
        allocator.free(column_names);
    }

    for (0..column_count) |column_index| {
        var name_view = c.shovelerdb_string_view{ .data = null, .len = 0 };
        const status = c.shovelerdb_result_column_name(result, column_index, &name_view);
        if (status != c.SHOVELERDB_STATUS_OK) return statusError(status);
        column_names[column_index] = try copyByteView(allocator, name_view.data, name_view.len);
        names_initialized += 1;
    }

    const row_count = c.shovelerdb_result_row_count(result);
    const rows = try allocator.alloc(OwnedRow, row_count);
    var rows_initialized: usize = 0;
    errdefer {
        for (rows[0..rows_initialized]) |*row| row.deinit(allocator);
        allocator.free(rows);
    }

    while (rows_initialized < row_count) : (rows_initialized += 1) {
        var raw_row: ?*const c.shovelerdb_row = null;
        const status = c.shovelerdb_result_next(result, &raw_row);
        if (status != c.SHOVELERDB_STATUS_OK) return statusError(status);
        rows[rows_initialized] = try copyRow(
            allocator,
            raw_row orelse return error.Internal,
            column_count,
        );
    }

    var extra_row: ?*const c.shovelerdb_row = null;
    const end_status = c.shovelerdb_result_next(result, &extra_row);
    if (end_status != c.SHOVELERDB_STATUS_OK or extra_row != null) return error.Internal;

    return .{ .column_names = column_names, .rows = rows };
}

fn copyRow(
    allocator: std.mem.Allocator,
    row: *const c.shovelerdb_row,
    column_count: usize,
) !OwnedRow {
    const values = try allocator.alloc(OwnedValue, column_count);
    var initialized: usize = 0;
    errdefer {
        for (values[0..initialized]) |*value| value.deinit(allocator);
        allocator.free(values);
    }

    for (0..column_count) |column_index| {
        values[column_index] = try copyValue(allocator, row, column_index);
        initialized += 1;
    }
    return .{ .values = values };
}

fn copyValue(
    allocator: std.mem.Allocator,
    row: *const c.shovelerdb_row,
    column_index: usize,
) !OwnedValue {
    var kind: c.shovelerdb_value_kind = c.SHOVELERDB_VALUE_NULL;
    var status = c.shovelerdb_row_value_kind(row, column_index, &kind);
    if (status != c.SHOVELERDB_STATUS_OK) return statusError(status);

    return switch (kind) {
        c.SHOVELERDB_VALUE_NULL => .null_value,
        c.SHOVELERDB_VALUE_INTEGER => value: {
            var out: i64 = 0;
            status = c.shovelerdb_row_value_int64(row, column_index, &out);
            if (status != c.SHOVELERDB_STATUS_OK) return statusError(status);
            break :value .{ .integer = out };
        },
        c.SHOVELERDB_VALUE_FLOAT => value: {
            var out: f64 = 0;
            status = c.shovelerdb_row_value_float64(row, column_index, &out);
            if (status != c.SHOVELERDB_STATUS_OK) return statusError(status);
            break :value .{ .float = out };
        },
        c.SHOVELERDB_VALUE_BOOLEAN => value: {
            var out: u8 = 0;
            status = c.shovelerdb_row_value_bool(row, column_index, &out);
            if (status != c.SHOVELERDB_STATUS_OK) return statusError(status);
            break :value .{ .boolean = out != 0 };
        },
        c.SHOVELERDB_VALUE_TEXT => value: {
            var view = c.shovelerdb_string_view{ .data = null, .len = 0 };
            status = c.shovelerdb_row_value_text(row, column_index, &view);
            if (status != c.SHOVELERDB_STATUS_OK) return statusError(status);
            break :value .{ .text = try copyByteView(allocator, view.data, view.len) };
        },
        c.SHOVELERDB_VALUE_BLOB => value: {
            var view = c.shovelerdb_bytes_view{ .data = null, .len = 0 };
            status = c.shovelerdb_row_value_blob(row, column_index, &view);
            if (status != c.SHOVELERDB_STATUS_OK) return statusError(status);
            break :value .{ .blob = try copyByteView(allocator, view.data, view.len) };
        },
        c.SHOVELERDB_VALUE_VECTOR_F32 => value: {
            var view = c.shovelerdb_f32_vector_view{ .data = null, .len = 0 };
            status = c.shovelerdb_row_value_vector_f32(row, column_index, &view);
            if (status != c.SHOVELERDB_STATUS_OK) return statusError(status);
            if (view.len > 0 and view.data == null) return error.Internal;
            const source = if (view.len == 0) &[_]f32{} else view.data[0..view.len];
            break :value .{ .vector_f32 = try allocator.dupe(f32, source) };
        },
        else => error.Internal,
    };
}

fn copyByteView(
    allocator: std.mem.Allocator,
    data: ?[*c]const u8,
    len: usize,
) ![]u8 {
    const source = if (len == 0) &[_]u8{} else data.?[0..len];
    return allocator.dupe(u8, source);
}

fn lockMutex(mutex: *std.atomic.Mutex) void {
    while (!mutex.tryLock()) std.atomic.spinLoopHint();
}

pub const testing = if (builtin.is_test) struct {
    pub fn copyLastDiagnostic(adapter: *Adapter, allocator: std.mem.Allocator) ![]u8 {
        lockMutex(&adapter.mutex);
        defer adapter.mutex.unlock();

        const handle = adapter.handle orelse return error.Closed;
        var code: c.shovelerdb_diagnostic_code = c.SHOVELERDB_DIAGNOSTIC_NONE;
        var message = c.shovelerdb_string_view{ .data = null, .len = 0 };
        const status = c.shovelerdb_database_last_diagnostic(handle, &code, &message);
        if (status != c.SHOVELERDB_STATUS_OK) return statusError(status);
        return copyByteView(allocator, message.data, message.len);
    }
} else struct {};

test "ABI version is exactly 0.1.0" {
    try std.testing.expect(abiVersion().isExpected());
}

test "text literal encoder preserves data and doubles only apostrophes" {
    const allocator = std.testing.allocator;
    const cases = [_]struct { input: []const u8, expected: []const u8 }{
        .{ .input = "", .expected = "''" },
        .{ .input = "O'Reilly", .expected = "'O''Reilly'" },
        .{ .input = "a'; DROP TABLE wp04_probe; --", .expected = "'a''; DROP TABLE wp04_probe; --'" },
        .{ .input = "/* comment */; -- comment", .expected = "'/* comment */; -- comment'" },
        .{ .input = "slash\\/\t\r\nnaïve 猫", .expected = "'slash\\/\t\r\nnaïve 猫'" },
    };

    for (cases) |case| {
        const encoded = try encodeTextLiteral(allocator, case.input);
        defer allocator.free(encoded);
        try std.testing.expectEqualStrings(case.expected, encoded);
    }
}

test "text literal encoder rejects embedded NUL before allocation" {
    try std.testing.expectError(
        error.EmbeddedNul,
        encodeTextLiteral(std.testing.allocator, "before\x00after"),
    );
}

test "stable categories contain no engine prose" {
    try std.testing.expectEqual(ErrorCategory.parse, category(error.Parse));
    try std.testing.expectEqual(ErrorCategory.persistence, category(error.Persistence));
    try std.testing.expectEqual(ErrorCategory.embedded_nul, category(error.EmbeddedNul));
    try std.testing.expectEqual(
        ErrorCategory.binding_arity_mismatch,
        category(error.BindingArityMismatch),
    );
}
