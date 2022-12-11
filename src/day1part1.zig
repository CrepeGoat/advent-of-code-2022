const std = @import("std");

const iter_tools = @import("utils/iterator.zig");
const input_tools = @import("common/input.zig");

fn getMaxCalories(iterator: anytype) u32 {
    var count = 0;
    while (iterator.next()) |item| {
        count += item;
    }
    return count;
}

fn groupPredicate(buffer: []const u8) bool {
    return buffer.len > 0;
}

fn strToInt(buffer: []const u8) !u32 {
    return std.fmt.parseInt(u32, buffer, 10);
}

fn mapStrIterToU32Iter(iterator: anytype) iter_tools.IterMap(@TypeOf(iterator), []const u8, u32) {
    return iter_tools.iterMap(iterator, strToInt);
}

pub fn main(stdin: anytype, stdout: anytype) !void {
    var buffer: [10]u8 = undefined;
    var stdin_iter = input_tools.readerReadUntilDelimiterOrEofIterator(
        stdin,
        &buffer,
        '\n',
    );

    var iteriter_str = iter_tools.iterGroupWhile(stdin_iter, groupPredicate, false);
    var iteriter_u32 = iter_tools.iterMap(iteriter_str, mapStrIterToU32Iter);

    var max_calories: u32 = 0;
    while (iteriter_u32.next()) |iterator| {
        max_calories = std.math.max(max_calories, getMaxCalories(iterator));
    }

    stdout.write(max_calories);
}
