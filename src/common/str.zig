const std = @import("std");

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

pub fn splitIntoN(comptime T: type, comptime N: usize, buffer: []const T, delimiter: []const T) ![N][]const T {
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
