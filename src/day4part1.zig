const std = @import("std");

pub fn main(stdin: anytype, stdout: anytype) !void {
    const result = try countNestedRangePairs(stdin);

    var buffer: [100]u8 = undefined;
    _ = try stdout.write(try std.fmt.bufPrint(&buffer, "{d}\n", .{result}));
}

test "counted nested range pairs - e.g. input" {
    var stdin = try std.fs.cwd().openFile(
        "inputs/day4-input-eg.txt",
        .{ .mode = std.fs.File.OpenMode.read_only },
    );
    defer stdin.close();

    const calc_result = try countNestedRangePairs(stdin.reader());
    const expt_result = 2;
    try std.testing.expectEqual(calc_result, expt_result);
}

test "counted nested range pairs - true input" {
    var stdin = try std.fs.cwd().openFile(
        "inputs/day4-input.txt",
        .{ .mode = std.fs.File.OpenMode.read_only },
    );
    defer stdin.close();

    const calc_result = try countNestedRangePairs(stdin.reader());
    const expt_result = 513;
    try std.testing.expectEqual(calc_result, expt_result);
}

pub fn countNestedRangePairs(stdin: anytype) !u32 {
    var buffer: [12]u8 = undefined;

    var score: u32 = 0;
    while (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |str| {
        const ranges = try parseRangePair(u32, str);
        if (ranges[0].contains(ranges[1]) or ranges[1].contains(ranges[0])) {
            score += 1;
        }
    }

    return score;
}

fn parseRangePair(comptime NumType: type, str: []const u8) ![2]Range(NumType) {
    var str_parts = try splitIntoN(u8, 2, str, &[_]u8{','});

    return .{ try Range(NumType).parse(str_parts[0]), try Range(NumType).parse(str_parts[1]) };
}

test "split into N" {
    const N = 2;
    const str = [_]u8{ 'h', 'e', 'l', 'l', 'o', ' ', 'u' };

    const calc_result = try splitIntoN(u8, 2, &str, &[_]u8{' '});
    const expt_result: @TypeOf(calc_result) = [_][]const u8{ &[_]u8{ 'h', 'e', 'l', 'l', 'o' }, &[_]u8{'u'} };

    var i: usize = 0;
    while (i < N) : (i += 1) {
        try std.testing.expectEqualSlices(u8, expt_result[i], calc_result[i]);
    }
}

fn splitIntoN(comptime T: type, comptime N: usize, buffer: []const T, delimiter: []const T) ![N][]const T {
    var result: [N][]const T = undefined;

    var str_parts = std.mem.split(u8, buffer, delimiter);

    for (result) |sub_buffer, index| {
        _ = sub_buffer;
        result[index] = if (str_parts.next()) |str_part| str_part else {
            return error.Failure;
        };
    }
    if (str_parts.next() != null) {
        return error.Failure;
    }

    return result;
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
    };
}
