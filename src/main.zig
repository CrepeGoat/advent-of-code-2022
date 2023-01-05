const std = @import("std");
const src = @import("day14part1.zig");

pub fn main() anyerror!void {
    try src.main(std.io.getStdIn().reader(), std.io.getStdOut().writer());
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
