const std = @import("std");

fn lessThan(context: void, lhs: u32, rhs: u32) bool {
    _ = context;
    return lhs < rhs;
}

fn queuePush(array: []u32, item: u32) u32 {
    const argMin = std.sort.argMin(u32, array, {}, lessThan).?;
    defer if (array[argMin] < item) {
        array[argMin] = item;
    };
    return array[argMin];
}

pub fn main(stdin: anytype, stdout: anytype) !void {
    var buffer: [10]u8 = undefined;

    var max_calories = [3]u32{ 0, 0, 0 };
    var calorie_count: u32 = 0;

    while (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |str| {
        if (str.len == 0) {
            defer calorie_count = 0;
            _ = queuePush(&max_calories, calorie_count);
        } else {
            calorie_count += try std.fmt.parseInt(u32, str, 10);
        }
    } else {
        _ = queuePush(&max_calories, calorie_count);
    }

    var calorie_sum: u32 = 0;
    for (max_calories) |cals| {
        calorie_sum += cals;
    }
    _ = try stdout.write(try std.fmt.bufPrint(&buffer, "{d}\n", .{calorie_sum}));
}
