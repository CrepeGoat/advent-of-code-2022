const std = @import("std");
const src = @import("day1part1.zig");

pub fn main() anyerror!void {
    try src.main(std.io.getStdIn(), std.io.getStdOut());
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
