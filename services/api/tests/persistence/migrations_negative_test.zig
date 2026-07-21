const std = @import("std");
const migrations = @import("migrations");

test "migration negative producer is build-wired" {
    std.testing.refAllDecls(migrations);
}
