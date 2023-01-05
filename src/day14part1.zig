const std = @import("std");
const stdio = @import("common/stdio.zig");
const splitIntoN = @import("common/str.zig").splitIntoN;

// test "find start of packet marker - full input" {
//     const alloc = std.testing.allocator;

//     const filename = "inputs/day14-input.txt";
//     var file = try std.fs.cwd().openFile(
//         filename,
//         .{ .mode = std.fs.File.OpenMode.read_only },
//     );
//     defer file.close();
//     var in = file.reader();

//     var out_buffer = std.ArrayList(u8).init(alloc);
//     defer out_buffer.deinit();
//     var out = out_buffer.writer();

//     try main(in, &out);
//     try std.testing.expectEqualSlices(u8, "3051\n", out_buffer.items);
// }

pub fn main(stdin: anytype, stdout: anytype) !void {
    const T = i32;

    var alloc_buffer: [4096]u8 = undefined;

    const result = blk: {
        var fba = std.heap.FixedBufferAllocator.init(&alloc_buffer);
        const alloc = fba.allocator();

        var line_iter = stdio.readerReadUntilDelimiterOrEofAllocIterator(alloc, stdin, '\n', std.math.maxInt(usize));
        const rock_paths = try RockPath(T).parseList(alloc, line_iter);
        defer rock_paths.deinit();

        const filled_area_map = try fillSandAt(T, alloc, rock_paths, Point(T){ .x = 500, .y = 0 });
        defer filled_area_map.deinit();

        break :blk filled_area_map.countSands();
    };

    try stdout.write(try std.fmt.bufPrint(&alloc_buffer, "{}\n", .{result}));
}

/// Runs the sand simulation, given an initial rock formation and starting
/// point.
fn fillSandAt(
    comptime T: type,
    alloc: std.mem.Allocator,
    rock_paths: std.ArrayList(RockPath(T)),
    location: Point(T),
) !AreaMap(T) {
    var area_map = AreaMap(T).init(alloc, rock_paths);
    errdefer area_map.deinit();
    var sand_path = SandPathStreaks.init(alloc);
    defer sand_path.deinit();
    var loc = location;

    while (true) {
        // Check if sand falls into the endless void
        if (area_map.endless_void_line == null or loc.y >= area_map.endless_void_line.?) {
            return area_map;
        }

        // Check if sand can fit at location
        const loc_fall_mid = Point(T){ .x = loc.x, .y = loc.y + 1 };
        if (!area_map.isFilledAt(loc_fall_mid)) {
            try sand_path.append(.middle);
            loc = loc_fall_mid;
            continue;
        }

        const loc_fall_right = Point(T){ .x = loc.x + 1, .y = loc.y + 1 };
        if (!area_map.isFilledAt(loc_fall_right)) {
            try sand_path.append(.right);
            loc = loc_fall_right;
            continue;
        }

        const loc_fall_left = Point(T){ .x = loc.x - 1, .y = loc.y + 1 };
        if (!area_map.isFilledAt(loc_fall_left)) {
            try sand_path.append(.left);
            loc = loc_fall_left;
            continue;
        }

        // sand can't fall -> store streak
        if (sand_path.path.items.len == 0) {
            // sand filled up to entry point -> end
            try area_map.resting_sands_singles.put(loc, .{});
            return area_map;
        }

        const last_streak = sand_path.path.items[sand_path.path.items.len - 1];
        switch (last_streak.item) {
            .middle => {
                // move up one block
                try area_map.resting_sands_singles.put(loc, .{});
                loc.y -= 1;
            },
            .left => {
                const loc_posdiag = loc.toPosDiag();
                const loc_posdiag_back_streak = Point(T){
                    .x = loc.x + last_streak.count,
                    .y = loc.y - last_streak.count,
                };
                // move up-right N blocks
                area_map.resting_sands_posdiag.append(
                    CustomAxisLine(T, .positive_diagonal).fromPoints(
                        loc_posdiag,
                        loc_posdiag_back_streak,
                    ),
                );
                loc.y -= 1;
            },
            .right => {
                const loc_posdiag = loc.toPosDiag();
                const loc_posdiag_back_streak = Point(T){
                    .x = loc.x - last_streak.count,
                    .y = loc.y - last_streak.count,
                };
                // move up-right N blocks
                area_map.resting_sands_posdiag.append(
                    CustomAxisLine(T, .positive_diagonal).fromPoints(
                        loc_posdiag,
                        loc_posdiag_back_streak,
                    ),
                );
                loc.y -= 1;
            },
        }
    }
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
        resting_sands_singles: std.AutoHashMap(Point(T), @TypeOf(.{})),

        pub fn init(
            alloc: std.mem.Allocator,
            rock_paths: std.ArrayList(RockPath(T)),
        ) Self {
            const indexed_rock_paths = indexRockPaths(T, alloc, rock_paths);

            return .{
                .rocks_vert = indexed_rock_paths[0],
                .rocks_horiz = indexed_rock_paths[1],
                .endless_void_line = indexed_rock_paths[2],
                .resting_sands_negdiag = LinesMap(T, .negative_diagonal).init(alloc),
                .resting_sands_posdiag = LinesMap(T, .positive_diagonal).init(alloc),
                .resting_sands_singles = std.AutoHashMap(Point(T), .{}).init(alloc),
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
            if (self.resting_sands_singles.containsAdapted(pos, .{})) {
                return true;
            }

            return false;
        }

        pub fn countSands(self: Self) usize {
            var count = 0;
            inline for (.{ self.resting_sands_posdiag, self.resting_sands_negdiag }) |sand_lines_map| {
                for (sand_lines_map.lines.items) |sand_line| {
                    count += sand_line.len();
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
) .{ LinesMap(T, .vertical), LinesMap(T, .horizontal), ?T } {
    var vert_lines = LinesMap(T, .vertical).init(alloc);
    var horiz_lines = LinesMap(T, .horizontal).init(alloc);
    var any_lowest_y: ?T = null;
    for (rock_paths.items) |rock_path| {
        switch (rock_path) {
            .Vertical => |vert_path| {
                vert_lines.append(vert_path);
                any_lowest_y = if (any_lowest_y) |lowest_y| std.sort.max(lowest_y, vert_path.pos2) else vert_path.pos2;
            },
            .Horizontal => |horiz_path| {
                horiz_lines.append(horiz_path);
                any_lowest_y = if (any_lowest_y) |lowest_y| std.sort.max(lowest_y, horiz_path.offset) else horiz_path.offset;
            },
        }
    }

    return .{ vert_lines, horiz_lines, any_lowest_y };
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
const SandPathStreaks = struct {
    const Self = @This();

    path: std.ArrayList(Streak(SandPath)),

    pub fn init(alloc: std.mem.Allocator) Self {
        return .{ .path = .init(alloc) };
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

/// The direction in which sand flowed from a higher height to an adjacent lower
/// height.
const SandPath = enum {
    left,
    middle,
    right,
};

fn Streak(comptime ItemType: type) type {
    return struct {
        item: ItemType,
        count: usize,
    };
}

/// A data structure for indexing parallel lines of discrete spatial data.
fn LinesMap(comptime T: type, comptime axis: Axes) type {
    return struct {
        const Self = @This();

        alloc: std.mem.Allocator,
        lines: std.AutoHashMap(T, std.ArrayList(CustomAxisLine(T, axis))),

        pub fn init(alloc: std.mem.Allocator) Self {
            return .{ .alloc = alloc, .lines = .init(alloc) };
        }

        pub fn deinit(self: *Self) void {
            for (self.lines.valueIterator()) |lines_array| {
                lines_array.deinit();
            }
            self.lines.deinit();
        }

        pub fn append(self: *Self, axis_line: CustomAxisLine(T, axis)) !void {
            var lines_array = self.lines.getOrPut(axis_line.axis_offset);
            if (lines_array == undefined) {
                lines_array = std.ArrayList(CustomAxisLine(T, axis)).init(self.alloc);
            }

            // TODO: replace lines_array with a data structure that has faster sorted insertions
            const insertion_index = bisect(
                CustomAxisLine(T, axis),
                T,
                self.lines_array.items,
                axis_line.pos2,
                .{},
                PosToLineEndComparator(T).call,
                .after,
            );
            try lines_array.insert(insertion_index, axis_line);
        }

        pub fn isFilledAt(self: Self, axis_pos: CustomAxisPoint(T)) bool {
            if (!self.lines.get(axis_pos.offset)) {
                return false;
            } else |lines_array| {
                const insertion_index = bisect(
                    CustomAxisLine(T, axis),
                    T,
                    self.lines_array.items,
                    axis_pos.pos,
                    .{},
                    PosToLineEndComparator(T, axis).call,
                    .after,
                );

                if (!(insertion_index < self.lines.items.len)) {
                    return false;
                }

                std.debug.assert(axis_pos.pos <= lines_array.items[insertion_index].pos2); // guaranteed by bisect
                return lines_array.items[insertion_index].pos1 <= axis_pos.pos;
            }
        }
    };
}

fn bisect(
    comptime T: type,
    comptime K: type,
    items: []T,
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
        switch (.{ comparator(context, key, items[mid]), insertion_point }) {
            .{ .lt, .before | .after } | .{ .eq, .before } => right = mid,
            .{ .gt, .before | .after } | .{ .eq, .after } => left = mid + 1,
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
        const calc_result = PosToLineEndComparator(T, axis).call(.{}, value, line_after);
        try std.testing.expectEqual(std.math.Order.lt, calc_result);
    }

    {
        const line_at = CustomAxisLine(T, axis){ .axis_offset = 1, .pos1 = -1, .pos2 = 3 };
        const calc_result = PosToLineEndComparator(T, axis).call(.{}, value, line_at);
        try std.testing.expectEqual(std.math.Order.eq, calc_result);
    }

    {
        const line_before = CustomAxisLine(T, axis){ .axis_offset = 1, .pos1 = -1, .pos2 = 0 };
        const calc_result = PosToLineEndComparator(T, axis).call(.{}, value, line_before);
        try std.testing.expectEqual(std.math.Order.gt, calc_result);
    }
}

fn PosToLineEndComparator(comptime T: type, comptime axis: Axes) type {
    return struct {
        fn call(context: @TypeOf(.{}), key: T, line: CustomAxisLine(T, axis)) std.math.Order {
            _ = context;
            return std.math.order(key, line.pos2);
        }
    };
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

        pub fn len(self: Self) T {
            return switch (axis) {
                .vertical | .horizontal => self.pos2 - self.pos1,
                .positive_diagonal | .negative_diagonal => (self.pos2 - self.pos1) / 2,
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
}

test "convert cartesian point to horizontal coords" {
    const Int = i32;

    const pos1 = Point(Int){ .x = 1, .y = 3 };
    const pos2 = Point(Int){ .x = 2, .y = 3 };

    const pos1axis = pos1.toHorizontal();
    const pos2axis = pos2.toHorizontal();

    try std.testing.expectEqual(pos1axis.axis_offset, pos2axis.axis_offset);
}

test "convert cartesian point to positive diagonal coords" {
    const Int = i32;

    const pos1 = Point(Int){ .x = 1, .y = 2 };
    const pos2 = Point(Int){ .x = 5, .y = 6 };

    const pos1axis = pos1.toPosDiag();
    const pos2axis = pos2.toPosDiag();

    try std.testing.expectEqual(pos1axis.axis_offset, pos2axis.axis_offset);
}

test "convert cartesian point to negative diagonal coords" {
    const Int = i32;

    const pos1 = Point(Int){ .x = 1, .y = 5 };
    const pos2 = Point(Int){ .x = 2, .y = 4 };

    const pos1axis = pos1.toNegDiag();
    const pos2axis = pos2.toNegDiag();

    try std.testing.expectEqual(pos1axis.axis_offset, pos2axis.axis_offset);
}

fn Point(comptime T: type) type {
    return struct {
        const Self = @This();

        x: T,
        y: T,

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
