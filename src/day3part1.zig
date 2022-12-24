const std = @import("std");

fn parseRucksack(items: []const u8) !?[2][]const u8 {
    if (items.len % 2 != 0) {
        return error.Failure;
    }
    const half_len = items.len / 2;
    return .{ items[0..half_len], items[half_len..] };
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

fn getCommonItem(items1: []const u8, items2: []const u8) !Item {
    var compartment1 = [_]bool{false} ** 64;
    for (items1) |item_code| {
        const item1 = try Item.parse(item_code);
        compartment1[item1.id()] = true;
    }

    return for (items2) |item_code| {
        const item2 = try Item.parse(item_code);
        if (compartment1[item2.id()]) {
            break item2;
        }
    } else error.Failure;
}

pub fn main(stdin: anytype, stdout: anytype) !void {
    var buffer: [100]u8 = undefined;

    var score: u32 = 0;
    while (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |str| {
        if (try parseRucksack(str)) |rucksack| {
            const commonItem = try getCommonItem(rucksack[0], rucksack[1]);
            score += commonItem.score();
        }
    }

    _ = try stdout.write(try std.fmt.bufPrint(&buffer, "{d}\n", .{score}));
}
