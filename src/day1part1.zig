const std = @import("std");

const iter_tools = @import("utils/iterator.zig");
const input_tools = @import("common/input.zig");

fn getMaxCalories(iterator: anytype) !?u32 {
    var iterator_mut = iterator;
    var count: ?u32 = null;
    while (try iterator_mut.next()) |item| {
        count = (count orelse 0) + item;
    }
    return count;
}

fn whilePredicate(buffer: []const u8) bool {
    return buffer.len > 0;
}

fn strToInt(buffer: []const u8) !u32 {
    return std.fmt.parseInt(u32, buffer, 10);
}

pub fn main(stdin: anytype, stdout: anytype) !void {
    var buffer: [10]u8 = undefined;
    var stdin_iter = input_tools.readerReadUntilDelimiterOrEofIterator(
        stdin.reader(),
        &buffer,
        '\n',
    );

    var max_calories: u32 = 0;
    while (true) {
        var iter = stdin_iter.iterWhile(whilePredicate, false).iterMap(strToInt);
        if (try getMaxCalories(iter)) |cals| {
            max_calories = std.math.max(max_calories, cals);
        } else {
            break;
        }
    }

    _ = try stdout.write(try std.fmt.bufPrint(&buffer, "{d}\n", .{max_calories}));
}
