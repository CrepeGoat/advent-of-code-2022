const std = @import("std");
const splitIntoN = @import("src/common/str.zig").splitIntoN;

pub fn main(stdin: anytype, stdout: anytype) !void {
    const result = try countOverlappingRangePairs(stdin);

    var buffer: [100]u8 = undefined;
    _ = try stdout.write(try std.fmt.bufPrint(&buffer, "{d}\n", .{result}));
}

test "counted nested range pairs - e.g. input" {
    var stdin = try std.fs.cwd().openFile(
        "inputs/day4-input-eg.txt",
        .{ .mode = std.fs.File.OpenMode.read_only },
    );
    defer stdin.close();

    const calc_result = try countOverlappingRangePairs(stdin.reader());
    const expt_result = 4;
    try std.testing.expectEqual(calc_result, expt_result);
}

test "counted nested range pairs - true input" {
    var stdin = try std.fs.cwd().openFile(
        "inputs/day4-input.txt",
        .{ .mode = std.fs.File.OpenMode.read_only },
    );
    defer stdin.close();

    const calc_result = try countOverlappingRangePairs(stdin.reader());
    const expt_result = 878;
    try std.testing.expectEqual(calc_result, expt_result);
}

pub fn countOverlappingRangePairs(stdin: anytype) !u32 {
    var buffer: [12]u8 = undefined;

    var score: u32 = 0;
    while (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |str| {
        const ranges = try parseRangePair(u32, str);
        if (ranges[0].overlaps(ranges[1])) {
            score += 1;
        }
    }

    return score;
}

fn parseRangePair(comptime NumType: type, str: []const u8) ![2]Range(NumType) {
    var str_parts = try splitIntoN(u8, 2, str, &[_]u8{','});

    return .{ try Range(NumType).parse(str_parts[0]), try Range(NumType).parse(str_parts[1]) };
}

fn Range(comptime NumType: type) type {
    return struct {
        const Self = @This();
        lower: NumType,
        upper: NumType,

        pub fn parse(str: []const u8) !Self {
            const str_parts = try splitIntoN(u8, 2, str, &[_]u8{'-'});

            return .{
                .lower = try std.fmt.parseInt(u32, str_parts[0], 10),
                .upper = try std.fmt.parseInt(u32, str_parts[1], 10),
            };
        }

        pub fn contains(self: Self, rhs: Self) bool {
            return self.lower <= rhs.lower and self.upper >= rhs.upper;
        }

        pub fn overlaps(self: Self, rhs: Self) bool {
            return self.lower <= rhs.upper and rhs.lower <= self.upper;
        }
    };
}
