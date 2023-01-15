const std = @import("std");
const stdio = @import("common/stdio.zig");
const splitIntoN = @import("common/str.zig").splitIntoN;

test "count resting sands - e.g. input" {
    const alloc = std.testing.allocator;

    inline for (.{
        .{ "inputs/day14-input-eg.txt", "93\n" },
        .{ "inputs/day14-input.txt", "26283\n" },
    }) |in_out| {
        const filename = in_out[0];
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
        try std.testing.expectEqualSlices(u8, in_out[1], out_buffer.items);
    }
}

pub fn main(stdin: anytype, stdout: anytype) !void {
    const T = i32;

    var alloc_buffer: [1 << 21]u8 = undefined;

    const result = blk: {
        var fba = std.heap.FixedBufferAllocator.init(&alloc_buffer);
        const alloc = fba.allocator();

        var line_iter = stdio.readerReadUntilDelimiterOrEofAllocIterator(alloc, stdin, '\n', std.math.maxInt(usize));
        var rocks = try parseRockPaths(T, alloc, line_iter);
        defer rocks.deinit();

        var resting_sands = try fillSandAt(T, alloc, .{ .x = 500, .y = 0 }, rocks);
        defer resting_sands.deinit();

        break :blk resting_sands.count();
    };

    _ = try stdout.write(try std.fmt.bufPrint(&alloc_buffer, "{}\n", .{result}));
}

fn fillSandAt(
    comptime T: type,
    alloc: std.mem.Allocator,
    location: Point(T),
    rocks: std.AutoHashMap(Point(T), void),
) !std.AutoHashMap(Point(T), void) {
    var resting_sands = std.AutoHashMap(Point(T), void).init(alloc);
    errdefer resting_sands.deinit();

    if (rocks.contains(location)) {
        return resting_sands;
    }

    const y_floor = blk: {
        var result = location.y;
        var iter = rocks.keyIterator();
        while (iter.next()) |point| {
            result = std.math.max(result, point.y);
        }

        break :blk result + 2;
    };

    var sand_path = std.ArrayList(Point(T)).init(alloc);
    defer sand_path.deinit();
    try sand_path.append(location);

    loop: while (sand_path.popOrNull()) |loc| {
        // Check for floor
        if (loc.y + 1 < y_floor) {
            // Check if sand can fit at location
            inline for (.{
                Point(T){ .x = loc.x, .y = loc.y + 1 }, // middle
                Point(T){ .x = loc.x - 1, .y = loc.y + 1 }, // left
                Point(T){ .x = loc.x + 1, .y = loc.y + 1 }, // right
            }) |loc_falling| {
                if (!rocks.contains(loc_falling) and !resting_sands.contains(loc_falling)) {
                    try sand_path.append(loc);
                    try sand_path.append(loc_falling);
                    continue :loop;
                }
            }
        }

        // sand can't fall -> store resting sand
        try resting_sands.putNoClobber(loc, {});
    }

    return resting_sands;
}

fn parseRockPaths(
    comptime T: type,
    alloc: std.mem.Allocator,
    lines: anytype,
) !std.AutoHashMap(Point(T), void) {
    var result = std.AutoHashMap(Point(T), void).init(alloc);
    errdefer result.deinit();

    while (try lines.next()) |line| {
        var any_last_point: ?Point(T) = null;
        var point_str_iter = std.mem.split(u8, line, " -> ");

        while (point_str_iter.next()) |point_str| {
            const point = try Point(T).parse(point_str);

            if (any_last_point) |last_point| {
                if (last_point.x == point.x) {
                    const min_y = std.math.min(last_point.y, point.y);
                    const max_y = std.math.max(last_point.y, point.y);
                    var y = min_y;
                    while (y <= max_y) : (y += 1) {
                        try result.put(Point(T){ .x = point.x, .y = y }, {});
                    }
                } else if (last_point.y == point.y) {
                    const min_x = std.math.min(last_point.x, point.x);
                    const max_x = std.math.max(last_point.x, point.x);
                    var x = min_x;
                    while (x <= max_x) : (x += 1) {
                        try result.put(Point(T){ .x = x, .y = point.y }, {});
                    }
                } else {
                    return error.Failure;
                }
            }
            any_last_point = point;
        }
    }

    return result;
}

/// The direction in which sand flowed from a higher height to an adjacent lower
/// height.
const SandPath = enum {
    left,
    middle,
    right,
};

fn Point(comptime T: type) type {
    return struct {
        const Self = @This();

        x: T,
        y: T,

        pub fn eql(self: Self, other: Self) bool {
            return self.x == other.x and self.y == other.y;
        }

        pub fn parse(str: []const u8) !Self {
            const parts = try splitIntoN(u8, 2, str, ",");
            return .{
                .x = try std.fmt.parseInt(T, parts[0], 10),
                .y = try std.fmt.parseInt(T, parts[1], 10),
            };
        }
    };
}
