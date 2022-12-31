const std = @import("std");

test "find start of packet marker - full input" {
    const alloc = std.testing.allocator;

    const filename = "inputs/day6-input.txt";
    var file = try std.fs.cwd().openFile(
        filename,
        .{ .mode = std.fs.File.OpenMode.read_only },
    );
    defer file.close();
    var in = file.reader();

    var out_buffer = std.ArrayList(u8).init(alloc);
    defer out_buffer.deinit();
    var out = out_buffer.writer();

    try main(in, &out);
    try std.testing.expectEqualSlices(u8, "3051\n", out_buffer.items);
}

pub fn main(stdin: anytype, stdout: anytype) !void {
    var alloc_buffer: [4096]u8 = undefined;
    const maybe_line = try stdin.readUntilDelimiterOrEof(&alloc_buffer, '\n');
    if (maybe_line) |line| {
        const result = findStartOfMessageMarker(line);

        var buffer: [100]u8 = undefined;
        _ = try stdout.write(try std.fmt.bufPrint(&buffer, "{?d}\n", .{result}));
    } else {
        return error.Failure;
    }
}

test "find start of packet marker - e.g. inputs" {
    const test_cases = .{
        .{ "inputs/day6-input-eg0.txt", 19 },
        .{ "inputs/day6-input-eg1.txt", 23 },
        .{ "inputs/day6-input-eg2.txt", 23 },
        .{ "inputs/day6-input-eg3.txt", 29 },
        .{ "inputs/day6-input-eg4.txt", 26 },
    };

    inline for (test_cases) |test_case| {
        const filename = test_case[0];
        const expt_result = test_case[1];

        var file = try std.fs.cwd().openFile(
            filename,
            .{ .mode = std.fs.File.OpenMode.read_only },
        );
        defer file.close();
        var reader = file.reader();
        var alloc_buffer: [100]u8 = undefined;
        const line = (try reader.readUntilDelimiterOrEof(&alloc_buffer, '\n')).?;
        const calc_result = findStartOfMessageMarker(line).?;

        try std.testing.expectEqual(@intCast(usize, expt_result), calc_result);
    }
}

fn findStartOfMessageMarker(signal: []const u8) ?usize {
    const WINDOW_LEN = 14;
    if (signal.len < WINDOW_LEN) {
        return null;
    }

    var count_dupes: usize = 0;
    var counts = [1]usize{0} ** (std.math.maxInt(u8) + 1);
    var signal_buffer: [WINDOW_LEN]u8 = undefined;

    return for (signal) |signal_item, index| {
        const buffer_index = index % WINDOW_LEN;

        // Remove old item
        if (index >= WINDOW_LEN) {
            const old_item = signal_buffer[buffer_index];

            counts[old_item] -= 1;
            if (counts[old_item] == 1) {
                count_dupes -= 1;
            }
        }

        // Add in new item
        signal_buffer[buffer_index] = signal_item;
        if (counts[signal_item] == 1) {
            count_dupes += 1;
        }
        counts[signal_item] += 1;

        // Check if streak is valid
        if (index >= WINDOW_LEN - 1 and count_dupes == 0) {
            break index + 1;
        }
    } else null;
}
