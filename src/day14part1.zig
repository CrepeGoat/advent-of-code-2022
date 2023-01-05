const std = @import("std");
const stdio = @import("common/stdio.zig");
const splitIntoN = @import("common/str.zig").splitIntoN;

test "count resting sands - e.g. input" {
    const alloc = std.testing.allocator;

    inline for (.{
        .{ "inputs/day14-input-eg.txt", "24\n" },
        .{ "inputs/day14-input.txt", "24\n" },
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

    var alloc_buffer: [1 << 20]u8 = undefined;

    const result = blk: {
        var fba = std.heap.FixedBufferAllocator.init(&alloc_buffer);
        const alloc = fba.allocator();

        var line_iter = stdio.readerReadUntilDelimiterOrEofAllocIterator(alloc, stdin, '\n', std.math.maxInt(usize));
        var rock_paths = try RockPath(T).parseList(alloc, line_iter);
        defer rock_paths.deinit();

        var area_map = try AreaMap(T).init(alloc, rock_paths);
        try area_map.fillSandAt(alloc, .{ .x = 500, .y = 0 });
        defer area_map.deinit();

        break :blk area_map.countSands();
    };

    _ = try stdout.write(try std.fmt.bufPrint(&alloc_buffer, "{}\n", .{result}));
}

/// A set of data structures collectively representing the occupied space on the
/// map by both rocks and resting sands.
fn AreaMap(comptime T: type) type {
    return struct {
        const Self = @This();

        rocks_vert: LinesMap(T, .vertical),
        rocks_horiz: LinesMap(T, .horizontal),
        endless_void_line: ?T,
        resting_sands_negdiag: LinesMap(T, .negative_diagonal),
        resting_sands_posdiag: LinesMap(T, .positive_diagonal),
        resting_sands_singles: std.AutoHashMap(Point(T), void),

        pub fn init(
            alloc: std.mem.Allocator,
            rock_paths: std.ArrayList(RockPath(T)),
        ) !Self {
            const indexed_rock_paths = try indexRockPaths(T, alloc, rock_paths);

            return .{
                .rocks_vert = indexed_rock_paths.vert_lines,
                .rocks_horiz = indexed_rock_paths.horiz_lines,
                .endless_void_line = indexed_rock_paths.void_floor,
                .resting_sands_negdiag = LinesMap(T, .negative_diagonal).init(alloc),
                .resting_sands_posdiag = LinesMap(T, .positive_diagonal).init(alloc),
                .resting_sands_singles = std.AutoHashMap(Point(T), void).init(alloc),
            };
        }

        pub fn deinit(self: *Self) void {
            self.rocks_vert.deinit();
            self.rocks_horiz.deinit();
            self.resting_sands_negdiag.deinit();
            self.resting_sands_posdiag.deinit();
            self.resting_sands_singles.deinit();
        }

        pub fn isFilledAt(self: Self, pos: Point(T)) bool {
            if (self.rocks_vert.isFilledAt(pos.toVertical())) {
                return true;
            }
            if (self.rocks_horiz.isFilledAt(pos.toHorizontal())) {
                return true;
            }
            if (self.resting_sands_negdiag.isFilledAt(pos.toNegDiag())) {
                return true;
            }
            if (self.resting_sands_posdiag.isFilledAt(pos.toPosDiag())) {
                return true;
            }
            if (self.resting_sands_singles.contains(pos)) {
                return true;
            }

            return false;
        }

        /// Runs the sand simulation, given an initial rock formation and starting
        /// point.
        fn fillSandAt(
            self: *Self,
            alloc: std.mem.Allocator,
            location: Point(T),
        ) !void {
            var sand_path = SandPathStreaks(T).init(alloc);
            defer sand_path.deinit();
            var loc = location;

            if (self.endless_void_line == null) {
                return error.Failure;
            }

            while (true) {
                // Check if sand falls into the endless void
                if (self.endless_void_line == null or loc.y >= self.endless_void_line.?) {
                    return;
                }

                // Check if sand can fit at location
                const loc_fall_mid = Point(T){ .x = loc.x, .y = loc.y + 1 };
                if (!self.isFilledAt(loc_fall_mid)) {
                    try sand_path.append(.middle);
                    loc = loc_fall_mid;
                    continue;
                }

                const loc_fall_left = Point(T){ .x = loc.x - 1, .y = loc.y + 1 };
                if (!self.isFilledAt(loc_fall_left)) {
                    try sand_path.append(.left);
                    loc = loc_fall_left;
                    continue;
                }

                const loc_fall_right = Point(T){ .x = loc.x + 1, .y = loc.y + 1 };
                if (!self.isFilledAt(loc_fall_right)) {
                    try sand_path.append(.right);
                    loc = loc_fall_right;
                    continue;
                }

                // sand filled up to entry point -> end
                if (sand_path.path.items.len == 0) {
                    try self.resting_sands_singles.put(loc, {});
                    return;
                }

                // sand can't fall -> store streak
                const last_streak = sand_path.path.items[sand_path.path.items.len - 1];
                switch (last_streak.item) {
                    .middle => {
                        // move up one block
                        try self.resting_sands_singles.put(loc, {});
                        loc.y -= 1;
                    },
                    .left => {
                        _ = sand_path.path.pop();
                        // move up-right N blocks
                        const loc_back_streak = Point(T){
                            .x = loc.x + last_streak.count,
                            .y = loc.y - last_streak.count,
                        };
                        defer loc = loc_back_streak;

                        try self.resting_sands_negdiag.append(
                            try CustomAxisLine(T, .negative_diagonal).fromPoints(
                                loc.toNegDiag(),
                                loc_back_streak.toNegDiag(),
                            ),
                        );
                    },
                    .right => {
                        _ = sand_path.path.pop();
                        // move up-right N blocks
                        const loc_back_streak = Point(T){
                            .x = loc.x - last_streak.count,
                            .y = loc.y - last_streak.count,
                        };
                        defer loc = loc_back_streak;

                        try self.resting_sands_posdiag.append(
                            try CustomAxisLine(T, .positive_diagonal).fromPoints(
                                loc.toPosDiag(),
                                loc_back_streak.toPosDiag(),
                            ),
                        );
                    },
                }
            }
        }

        pub fn countSands(self: Self) usize {
            var count: usize = 0;
            inline for (.{ self.resting_sands_posdiag, self.resting_sands_negdiag }) |sand_lines_map| {
                var iter = sand_lines_map.lines.valueIterator();
                while (iter.next()) |sand_lines| {
                    for (sand_lines.items) |sand_line| {
                        count += @intCast(usize, sand_line.len());
                    }
                }
            }
            count += self.resting_sands_singles.count();

            return count;
        }
    };
}

/// Convert from the input-given rock paths to an indexed data format.
fn indexRockPaths(
    comptime T: type,
    alloc: std.mem.Allocator,
    rock_paths: std.ArrayList(RockPath(T)),
) !IndexedRockPaths(T) {
    var vert_lines = LinesMap(T, .vertical).init(alloc);
    var horiz_lines = LinesMap(T, .horizontal).init(alloc);
    var any_lowest_y: ?T = null;
    for (rock_paths.items) |rock_path| {
        switch (rock_path) {
            .Vertical => |vert_path| {
                try vert_lines.append(vert_path);
                any_lowest_y = if (any_lowest_y) |lowest_y| std.math.max(lowest_y, vert_path.pos2) else vert_path.pos2;
            },
            .Horizontal => |horiz_path| {
                try horiz_lines.append(horiz_path);
                any_lowest_y = if (any_lowest_y) |lowest_y| std.math.max(lowest_y, horiz_path.axis_offset) else horiz_path.axis_offset;
            },
        }
    }

    return .{
        .vert_lines = vert_lines,
        .horiz_lines = horiz_lines,
        .void_floor = any_lowest_y,
    };
}

fn IndexedRockPaths(comptime T: type) type {
    return struct {
        vert_lines: LinesMap(T, .vertical),
        horiz_lines: LinesMap(T, .horizontal),
        void_floor: ?T,
    };
}

/// Represents a rock path, as provided directly from the input.
fn RockPath(comptime T: type) type {
    return union(enum) {
        const Self = @This();

        Vertical: CustomAxisLine(T, .vertical),
        Horizontal: CustomAxisLine(T, .horizontal),

        pub fn parseList(alloc: std.mem.Allocator, lines: anytype) !std.ArrayList(Self) {
            var result = std.ArrayList(Self).init(alloc);

            while (try lines.next()) |line| {
                var any_last_point: ?Point(T) = null;
                var point_str_iter = std.mem.split(u8, line, " -> ");

                while (point_str_iter.next()) |point_str| {
                    const point = try Point(T).parse(point_str);

                    if (any_last_point) |last_point| {
                        try result.append(try Self.fromPoints(last_point, point));
                    }
                    any_last_point = point;
                }
            }

            return result;
        }

        pub fn fromPoints(point1: Point(T), point2: Point(T)) !Self {
            if (point1.x == point2.x and point1.y == point2.y) {
                return error.Failure;
            }
            if (point1.x == point2.x) {
                return .{ .Vertical = try CustomAxisLine(T, .vertical).fromPoints(
                    point1.toVertical(),
                    point2.toVertical(),
                ) };
            }
            if (point1.y == point2.y) {
                return .{ .Horizontal = try CustomAxisLine(T, .horizontal).fromPoints(
                    point1.toHorizontal(),
                    point2.toHorizontal(),
                ) };
            }
            return error.Failure;
        }
    };
}

/// A sequence of SandPath streaks. Provides abstracted methods for treating
/// this as a normal sequence, while adding & detracting from individual
/// streaks.
fn SandPathStreaks(comptime INT: type) type {
    return struct {
        const Self = @This();

        path: std.ArrayList(Streak(INT, SandPath)),

        pub fn init(alloc: std.mem.Allocator) Self {
            return .{ .path = std.ArrayList(Streak(INT, SandPath)).init(alloc) };
        }

        pub fn deinit(self: *Self) void {
            self.path.deinit();
        }

        pub fn append(self: *Self, sand_move: SandPath) !void {
            if (self.path.items.len > 0) {
                var last_streak = &self.path.items[self.path.items.len - 1];
                if (last_streak.item == sand_move) {
                    last_streak.count += 1;
                    return;
                }
            }
            try self.path.append(.{ .item = sand_move, .count = 1 });
        }

        pub fn pop(self: *Self) ?SandPath {
            if (self.path.items.len == 0) {
                return null;
            }
            var last_streak = &self.path.items[self.path.items.len - 1];
            defer {
                last_streak.count -= 1;
                if (last_streak.count == 0) {
                    self.path.pop();
                }
            }
            return last_streak.item;
        }
    };
}

/// The direction in which sand flowed from a higher height to an adjacent lower
/// height.
const SandPath = enum {
    left,
    middle,
    right,
};

fn Streak(comptime INT: type, comptime ItemType: type) type {
    return struct {
        item: ItemType,
        count: INT,
    };
}

test "lines map" {
    var lines_map = LinesMap(i32, .positive_diagonal).init(std.testing.allocator);
    defer lines_map.deinit();

    const line1 = try CustomAxisLine(i32, .positive_diagonal).fromPoints(
        .{ .axis_offset = 0, .pos = 1 },
        .{ .axis_offset = 0, .pos = 5 },
    );
    const line2 = try CustomAxisLine(i32, .positive_diagonal).fromPoints(
        .{ .axis_offset = 0, .pos = 7 },
        .{ .axis_offset = 0, .pos = 9 },
    );
    const line3 = try CustomAxisLine(i32, .positive_diagonal).fromPoints(
        .{ .axis_offset = 2, .pos = -1 },
        .{ .axis_offset = 2, .pos = 2 },
    );

    inline for (.{ line1, line2, line3 }) |line| {
        try lines_map.append(line);
    }

    try std.testing.expect(lines_map.isFilledAt(.{ .axis_offset = 0, .pos = 1 }));
    try std.testing.expect(lines_map.isFilledAt(.{ .axis_offset = 0, .pos = 9 }));
    try std.testing.expect(lines_map.isFilledAt(.{ .axis_offset = 0, .pos = 8 }));
    try std.testing.expect(lines_map.isFilledAt(.{ .axis_offset = 2, .pos = 0 }));
    try std.testing.expect(!lines_map.isFilledAt(.{ .axis_offset = 0, .pos = 6 }));
    try std.testing.expect(!lines_map.isFilledAt(.{ .axis_offset = 1, .pos = 1 }));
}

/// A data structure for indexing parallel lines of discrete spatial data.
fn LinesMap(comptime T: type, comptime axis: Axes) type {
    return struct {
        const Self = @This();
        const sort_pos = RelativePosition.before;

        alloc: std.mem.Allocator,
        lines: std.AutoHashMap(T, std.ArrayList(CustomAxisLine(T, axis))),

        pub fn init(alloc: std.mem.Allocator) Self {
            return .{
                .alloc = alloc,
                .lines = std.AutoHashMap(
                    T,
                    std.ArrayList(CustomAxisLine(T, axis)),
                ).init(alloc),
            };
        }

        pub fn deinit(self: *Self) void {
            var iter = self.lines.valueIterator();
            while (iter.next()) |lines_array| {
                lines_array.deinit();
            }
            self.lines.deinit();
        }

        pub fn append(self: *Self, axis_line: CustomAxisLine(T, axis)) !void {
            var lines_array = try self.lines.getOrPut(axis_line.axis_offset);
            if (!lines_array.found_existing) {
                lines_array.value_ptr.* = std.ArrayList(CustomAxisLine(T, axis)).init(self.alloc);
            }

            // TODO: replace lines_array with a data structure that has faster sorted insertions
            const insertion_index = bisect(
                CustomAxisLine(T, axis),
                T,
                lines_array.value_ptr.*.items,
                axis_line.pos2,
                {},
                PosToLineEndComparator(T, axis).call,
                sort_pos,
            );
            try lines_array.value_ptr.*.insert(insertion_index, axis_line);
        }

        pub fn isFilledAt(self: Self, axis_pos: CustomAxisPoint(T, axis)) bool {
            if (self.lines.get(axis_pos.axis_offset)) |lines_array| {
                const insertion_index = bisect(
                    CustomAxisLine(T, axis),
                    T,
                    lines_array.items,
                    axis_pos.pos,
                    {},
                    PosToLineEndComparator(T, axis).call,
                    sort_pos,
                );

                if (!(insertion_index < lines_array.items.len)) {
                    return false;
                }

                std.debug.assert(axis_pos.pos <= lines_array.items[insertion_index].pos2); // guaranteed by bisect
                return lines_array.items[insertion_index].pos1 <= axis_pos.pos;
            } else {
                return false;
            }
        }
    };
}

test "bisect" {
    const items = [_]u8{ 2, 5 };

    try std.testing.expectEqual(bisect_no_context(u8, u8, &items, 0, std.math.order, .after), 0);
    try std.testing.expectEqual(bisect_no_context(u8, u8, &items, 2, std.math.order, .before), 0);
    try std.testing.expectEqual(bisect_no_context(u8, u8, &items, 2, std.math.order, .after), 1);
    try std.testing.expectEqual(bisect_no_context(u8, u8, &items, 3, std.math.order, .before), 1);
    try std.testing.expectEqual(bisect_no_context(u8, u8, &items, 3, std.math.order, .after), 1);
    try std.testing.expectEqual(bisect_no_context(u8, u8, &items, 5, std.math.order, .before), 1);
    try std.testing.expectEqual(bisect_no_context(u8, u8, &items, 5, std.math.order, .after), 2);
    try std.testing.expectEqual(bisect_no_context(u8, u8, &items, 6, std.math.order, .before), 2);
}

fn bisect_no_context(
    comptime T: type,
    comptime K: type,
    items: []const T,
    key: K,
    comptime comparator: anytype,
    comptime insertion_point: RelativePosition,
) usize {
    const comp = struct {
        pub fn call(context: void, lhs: K, rhs: T) std.math.Order {
            _ = context;
            return comparator(lhs, rhs);
        }
    };

    return bisect(T, K, items, key, {}, comp.call, insertion_point);
}

fn bisect(
    comptime T: type,
    comptime K: type,
    items: []const T,
    key: K,
    context: anytype,
    comptime comparator: fn (context: @TypeOf(context), lhs: K, rhs: T) std.math.Order,
    comptime insertion_point: RelativePosition,
) usize {
    var left: usize = 0;
    var right: usize = items.len;

    while (left < right) {
        // Avoid overflowing in the midpoint calculation
        const mid = left + (right - left) / 2;
        // Compare the key with the midpoint element
        const mapped_compare = switch (comparator(context, key, items[mid])) {
            .lt, .gt => |x| x,
            .eq => switch (insertion_point) {
                .before => .lt,
                .after => .gt,
            },
        };
        switch (mapped_compare) {
            .lt => right = mid,
            .gt => left = mid + 1,
            else => unreachable,
        }
    }

    return left;
}

const RelativePosition = enum {
    before,
    after,
};

test "compare pos to line end" {
    const T = i32;
    const axis = Axes.vertical;

    const value = 3;

    {
        const line_after = CustomAxisLine(T, axis){ .axis_offset = 1, .pos1 = -1, .pos2 = 5 };
        const calc_result = PosToLineEndComparator(T, axis).call({}, value, line_after);
        try std.testing.expectEqual(std.math.Order.lt, calc_result);
    }

    {
        const line_at = CustomAxisLine(T, axis){ .axis_offset = 1, .pos1 = -1, .pos2 = 3 };
        const calc_result = PosToLineEndComparator(T, axis).call({}, value, line_at);
        try std.testing.expectEqual(std.math.Order.eq, calc_result);
    }

    {
        const line_before = CustomAxisLine(T, axis){ .axis_offset = 1, .pos1 = -1, .pos2 = 0 };
        const calc_result = PosToLineEndComparator(T, axis).call({}, value, line_before);
        try std.testing.expectEqual(std.math.Order.gt, calc_result);
    }
}

fn PosToLineEndComparator(comptime T: type, comptime axis: Axes) type {
    return struct {
        fn call(context: void, key: T, line: CustomAxisLine(T, axis)) std.math.Order {
            _ = context;
            return std.math.order(key, line.pos2);
        }
    };
}

test "custom axis lines" {
    const line = try CustomAxisLine(i32, .positive_diagonal).fromPoints(
        .{ .axis_offset = 0, .pos = 1 },
        .{ .axis_offset = 0, .pos = 5 },
    );

    try std.testing.expect(try line.isFilledAt(.{ .axis_offset = 0, .pos = 1 }));
    try std.testing.expect(try line.isFilledAt(.{ .axis_offset = 0, .pos = 5 }));
    try std.testing.expect(!try line.isFilledAt(.{ .axis_offset = 0, .pos = -1 }));
    try std.testing.expect(!try line.isFilledAt(.{ .axis_offset = 0, .pos = 6 }));
    try std.testing.expectEqual(line.isFilledAt(.{ .axis_offset = 1, .pos = 1 }), error.Failure);
}

fn CustomAxisLine(comptime T: type, comptime axis: Axes) type {
    return struct {
        const Self = @This();
        const AXIS = axis;

        axis_offset: T,
        pos1: T,
        pos2: T,

        pub fn fromPoints(p1: CustomAxisPoint(T, axis), p2: CustomAxisPoint(T, axis)) !Self {
            if (p1.axis_offset != p2.axis_offset) {
                return error.Failure;
            }

            return .{
                .axis_offset = p1.axis_offset,
                .pos1 = std.math.min(p1.pos, p2.pos),
                .pos2 = std.math.max(p1.pos, p2.pos),
            };
        }

        pub fn isFilledAt(self: Self, point: CustomAxisPoint(T, axis)) !bool {
            if (self.axis_offset != point.axis_offset) {
                return error.Failure;
            }

            return self.pos1 <= point.pos and point.pos <= self.pos2;
        }

        pub fn len(self: Self) T {
            return switch (axis) {
                .vertical, .horizontal => self.pos2 - self.pos1,
                .positive_diagonal, .negative_diagonal => @divExact((self.pos2 - self.pos1), @as(T, 2)),
            };
        }
    };
}

test "convert cartesian point to vertical coords" {
    const Int = i32;

    const pos1 = Point(Int){ .x = 1, .y = 2 };
    const pos2 = Point(Int){ .x = 1, .y = 3 };

    const pos1axis = pos1.toVertical();
    const pos2axis = pos2.toVertical();

    try std.testing.expectEqual(pos1axis.axis_offset, pos2axis.axis_offset);
    try std.testing.expect(pos1axis.pos < pos2axis.pos);
}

test "convert cartesian point to horizontal coords" {
    const Int = i32;

    const pos1 = Point(Int){ .x = 1, .y = 3 };
    const pos2 = Point(Int){ .x = 2, .y = 3 };

    const pos1axis = pos1.toHorizontal();
    const pos2axis = pos2.toHorizontal();

    try std.testing.expectEqual(pos1axis.axis_offset, pos2axis.axis_offset);
    try std.testing.expect(pos1axis.pos < pos2axis.pos);
}

test "convert cartesian point to positive diagonal coords" {
    const Int = i32;

    const pos1 = Point(Int){ .x = 1, .y = 2 };
    const pos2 = Point(Int){ .x = 5, .y = 6 };

    const pos1axis = pos1.toPosDiag();
    const pos2axis = pos2.toPosDiag();

    try std.testing.expectEqual(pos1axis.axis_offset, pos2axis.axis_offset);
    try std.testing.expect(pos1axis.pos < pos2axis.pos);
}

test "convert cartesian point to negative diagonal coords" {
    const Int = i32;

    const pos1 = Point(Int){ .x = 2, .y = 4 };
    const pos2 = Point(Int){ .x = 1, .y = 5 };

    const pos1axis = pos1.toNegDiag();
    const pos2axis = pos2.toNegDiag();

    try std.testing.expectEqual(pos1axis.axis_offset, pos2axis.axis_offset);
    try std.testing.expect(pos1axis.pos < pos2axis.pos);
}

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

        pub fn toVertical(self: Self) CustomAxisPoint(T, .vertical) {
            return .{
                .axis_offset = self.x,
                .pos = self.y,
            };
        }

        pub fn toHorizontal(self: Self) CustomAxisPoint(T, .horizontal) {
            return .{
                .axis_offset = self.y,
                .pos = self.x,
            };
        }

        pub fn toPosDiag(self: Self) CustomAxisPoint(T, .positive_diagonal) {
            return .{
                .axis_offset = self.y - self.x,
                .pos = self.x + self.y,
            };
        }

        pub fn toNegDiag(self: Self) CustomAxisPoint(T, .negative_diagonal) {
            return .{
                .axis_offset = self.x + self.y,
                .pos = self.y - self.x,
            };
        }
    };
}

fn CustomAxisPoint(comptime T: type, comptime axis: Axes) type {
    return struct {
        const AXIS = axis;

        axis_offset: T,
        pos: T,
    };
}

const Axes = enum {
    vertical,
    horizontal,
    positive_diagonal,
    negative_diagonal,
};
