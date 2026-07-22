const std = @import("std");
const shared = @import("shared");

test "Sha256Digest decodes and emits its canonical prefixed form" {
    const text = "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";
    const value = try shared.Sha256Digest.parse(text);
    var output: [71]u8 = undefined;
    try std.testing.expectEqualSlices(u8, text, value.formatInto(&output));
}

test "Sha256Digest rejects prefix length and alphabet drift" {
    try std.testing.expectError(shared.DigestParseError.InvalidPrefix, shared.Sha256Digest.parse("SHA256:0000000000000000000000000000000000000000000000000000000000000000"));
    try std.testing.expectError(shared.DigestParseError.InvalidLength, shared.Sha256Digest.parse("sha256:0000"));
    try std.testing.expectError(shared.DigestParseError.InvalidAlphabet, shared.Sha256Digest.parse("sha256:A000000000000000000000000000000000000000000000000000000000000000"));
}
