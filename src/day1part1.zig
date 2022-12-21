const std = @import("std");

pub fn main(stdin: anytype, stdout: anytype) !void {
    var buffer: [10]u8 = undefined;

    var max_calories: u32 = 0;
    var calorie_count: u32 = 0;
    while (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |str| {
        if (str.len == 0) {
            defer calorie_count = 0;
            max_calories = std.math.max(max_calories, calorie_count);
        } else {
            calorie_count += try std.fmt.parseInt(u32, str, 10);
        }
    } else {
        max_calories = std.math.max(max_calories, calorie_count);
    }

    _ = try stdout.write(try std.fmt.bufPrint(&buffer, "{d}\n", .{max_calories}));
}
