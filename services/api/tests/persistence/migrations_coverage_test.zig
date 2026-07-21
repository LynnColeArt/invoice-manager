const std = @import("std");
const migrations = @import("migrations");

test "migration production declarations are analyzed" {
    std.testing.refAllDecls(migrations);
}
