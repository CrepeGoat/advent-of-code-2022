const std = @import("std");

pub fn main(stdin: anytype, stdout: anytype) !void {
    const score = try findBadgesSum(stdin);

    var buffer: [100]u8 = undefined;
    _ = try stdout.write(try std.fmt.bufPrint(&buffer, "{d}\n", .{score}));
}

test "find badges sum - e.g. input" {
    var stdin = try std.fs.cwd().openFile(
        "inputs/day3-input-eg.txt",
        .{ .mode = std.fs.File.OpenMode.read_only },
    );
    defer stdin.close();

    const calc_result = try findBadgesSum(stdin.reader());
    const expt_result = 70;
    try std.testing.expectEqual(calc_result, expt_result);
}

test "find badges sum - true input" {
    var stdin = try std.fs.cwd().openFile(
        "inputs/day3-input.txt",
        .{ .mode = std.fs.File.OpenMode.read_only },
    );
    defer stdin.close();

    const calc_result = try findBadgesSum(stdin.reader());
    const expt_result = 2639;
    try std.testing.expectEqual(calc_result, expt_result);
}

fn findBadgesSum(stdin: anytype) !u32 {
    const LEN = 3;
    const CountType = u2;

    var score: u32 = 0;
    outer: while (true) {
        var buffers: [LEN][100]u8 = undefined;
        var rucksacks: [LEN][]const u8 = undefined;
        var i: usize = 0;
        inner: while (i < LEN) : (i += 1) {
            if (try stdin.readUntilDelimiterOrEof(&buffers[i], '\n')) |rucksack| {
                if (rucksack.len > 0) {
                    rucksacks[i] = rucksack;
                    continue :inner;
                }
            }

            if (i == 0) {
                break :outer;
            }

            return error.Failure;
        }

        const badge = try findBadge(LEN, CountType, rucksacks);
        score += badge.score();
    }
    return score;
}

test "find badge" {
    const LEN = 3;
    const CountType = u2;

    var rucksacks: [LEN][]const u8 = .{
        &.{ 'h', 'e', 'l', 'l', 'o' },
        &.{ 't', 'h', 'e', 'r', 'e' },
        &.{ 'f', 'r', 'i', 'e', 'n', 'd' },
    };

    const calc_result = try findBadge(LEN, CountType, rucksacks);
    const expt_result = Item{ .code = 'e' };
    try std.testing.expectEqual(calc_result, expt_result);
}

fn findBadge(comptime LEN: usize, comptime CountType: type, rucksacks: [3][]const u8) !Item {
    var compartments = [_]CountType{0} ** 64;
    for (rucksacks) |rucksack| {
        try countUniqueItems(u2, &compartments, rucksack);
    }
    return for (compartments) |count, index| {
        if (count == LEN) {
            break try Item.fromId(@intCast(u8, index));
        }
    } else error.Failure;
}

test "count unique items" {
    const CountType = u1;
    var compartments = [_]CountType{0} ** 64;
    const items = [_]u8{ 'h', 'e', 'l', 'l', 'o' };

    const expt_result: [64]CountType = [_]CountType{0} ** 32 // A-Z + symbols
    ++ [_]CountType{0} ** 4 // a-d
    ++ [_]CountType{1} // e
    ++ [_]CountType{0} ** 2 // f, g
    ++ [_]CountType{1} // h
    ++ [_]CountType{0} ** 3 // i, j, k
    ++ [_]CountType{1} // l
    ++ [_]CountType{0} ** 2 // m, n
    ++ [_]CountType{1} // o
    ++ [_]CountType{0} ** 17; // p-z + symbols

    try countUniqueItems(CountType, &compartments, &items);
    try std.testing.expectEqualSlices(CountType, &compartments, &expt_result);
}

fn countUniqueItems(comptime CountType: type, compartments: *[64]CountType, items: []const u8) !void {
    var buffer: [64]Item = undefined;
    const dedouped_items = try dedoupItems(&buffer, items);
    for (dedouped_items) |item| {
        compartments[item.id()] += 1;
    }
}

test "dedoup items" {
    const item_codes = [_]u8{ 'h', 'e', 'l', 'l', 'o' };
    var buffer: [64]Item = undefined;

    const calc_result = try dedoupItems(&buffer, &item_codes);
    const expt_result = [_]Item{
        try Item.parse('e'),
        try Item.parse('h'),
        try Item.parse('l'),
        try Item.parse('o'),
    };

    try std.testing.expectEqualSlices(Item, calc_result, &expt_result);
}

fn dedoupItems(buffer: []Item, items: []const u8) ![]const Item {
    var compartments = [_]bool{false} ** 64;
    for (items) |item_code| {
        compartments[(try Item.parse(item_code)).id()] = true;
    }

    var index: usize = 0;
    for (compartments) |is_present, item_id| {
        if (!is_present) {
            continue;
        }
        defer index += 1;
        buffer[index] = try Item.fromId(@intCast(u8, item_id));
    }

    return buffer[0..index];
}

const Item = struct {
    const Self = @This();
    code: u8,

    pub fn parse(char: u8) !Self {
        if (!('A' <= char and char <= 'Z') and !('a' <= char and char <= 'z')) {
            return error.Failure;
        }
        return .{ .code = char };
    }

    pub fn fromId(char: u8) !Self {
        if (!(0 <= char and char <= 'z' - 'A')) {
            return error.Failure;
        }
        return .{ .code = char + 'A' };
    }

    pub fn id(self: Self) u8 {
        return self.code - 'A';
    }

    pub fn score(self: Self) u8 {
        return switch (self.code) {
            'a'...'z' => self.code - 'a' + 1,
            'A'...'Z' => self.code - 'A' + 27,
            else => unreachable,
        };
    }
};
