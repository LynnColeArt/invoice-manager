const std = @import("std");
const migrations = @import("migrations");

test "migration integration producer is build-wired" {
    std.testing.refAllDecls(migrations);
}
