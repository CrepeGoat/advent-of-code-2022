const std = @import("std");
const splitIntoN = @import("common/str.zig").splitIntoN;
const iterStdinReader = @import("common/stdio.zig").readerReadUntilDelimiterOrEofIterator;

test "main - e.g. input" {
    const alloc = std.testing.allocator;
    var file = try std.fs.cwd().openFile(
        "inputs/day5-input-eg.txt",
        .{ .mode = std.fs.File.OpenMode.read_only },
    );
    defer file.close();
    var in = file.reader();

    var out_buffer = std.ArrayList(u8).init(alloc);
    defer out_buffer.deinit();
    var out = out_buffer.writer();

    try main(in, &out);
    try std.testing.expectEqualSlices(u8, "CMZ\n", out_buffer.items);
}

test "main - full input" {
    const alloc = std.testing.allocator;
    var file = try std.fs.cwd().openFile(
        "inputs/day5-input.txt",
        .{ .mode = std.fs.File.OpenMode.read_only },
    );
    defer file.close();
    var in = file.reader();

    var out_buffer = std.ArrayList(u8).init(alloc);
    defer out_buffer.deinit();
    var out = out_buffer.writer();

    try main(in, &out);
    try std.testing.expectEqualSlices(u8, "FZCMJCRHZ\n", out_buffer.items);
}

pub fn main(stdin: anytype, stdout: anytype) !void {
    var alloc_buffer: [2000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&alloc_buffer);
    const alloc = fba.allocator();

    var crate_stacks = try CrateStacks(u8).read(alloc, stdin);
    defer crate_stacks.deinit();

    var line_iter = iterStdinReader(32, stdin, '\n');
    try rearrangeStacks(u8, &crate_stacks, line_iter);
    var result = try crate_stacks.stackTops();
    defer result.deinit();

    var buffer: [10]u8 = undefined;
    for (result.items) |char| {
        _ = try stdout.write(try std.fmt.bufPrint(&buffer, "{c}", .{char}));
    }
    _ = try stdout.write(try std.fmt.bufPrint(&buffer, "\n", .{}));
}

fn rearrangeStacks(comptime IdType: type, crate_stacks: *CrateStacks(IdType), line_iter: anytype) !void {
    while (try line_iter.next()) |line| {
        const instruction = try CrateStackInstruction.parse(line);

        var i: usize = 0;
        while (i < instruction.count) : (i += 1) {
            try crate_stacks.moveCrate(instruction.from_stack, instruction.to_stack);
        }
    }
}

test "CrateStacks.moveCrate" {
    const IdType = u8;
    const alloc = std.testing.allocator;
    var crate_stacks = CrateStacks(IdType).init(alloc);
    defer crate_stacks.deinit();
    try crate_stacks.stacks.append(std.ArrayList(IdType).init(alloc));
    try crate_stacks.stacks.items[0].append('1');
    try crate_stacks.stacks.items[0].append('2');
    try crate_stacks.stacks.append(std.ArrayList(IdType).init(alloc));
    try crate_stacks.stacks.items[1].append('3');
    try crate_stacks.stacks.append(std.ArrayList(IdType).init(alloc));
    try crate_stacks.stacks.append(std.ArrayList(IdType).init(alloc));
    try crate_stacks.stacks.items[3].append('4');
    try crate_stacks.stacks.items[3].append('5');

    // Check that array was initialized correctly
    const init_stacks = .{ [_]u8{ '1', '2' }, [_]u8{'3'}, [_]u8{}, [_]u8{ '4', '5' } };
    try std.testing.expectEqual(init_stacks.len, crate_stacks.stacks.items.len);
    inline for (init_stacks) |init_stack, index| {
        try std.testing.expectEqualSlices(u8, &init_stack, crate_stacks.stacks.items[index].items);
    }

    // Move crate from one stack to another, then check result
    try crate_stacks.moveCrate(0, 1);
    const expt_stacks = .{ [_]u8{'1'}, [_]u8{ '3', '2' }, [_]u8{}, [_]u8{ '4', '5' } };
    try std.testing.expectEqual(expt_stacks.len, crate_stacks.stacks.items.len);
    inline for (expt_stacks) |expt_stack, index| {
        try std.testing.expectEqualSlices(u8, &expt_stack, crate_stacks.stacks.items[index].items);
    }
}

fn CrateStacks(comptime IdType: type) type {
    return struct {
        const Self = @This();

        stacks: std.ArrayList(std.ArrayList(IdType)),

        pub fn init(alloc: std.mem.Allocator) Self {
            return .{ .stacks = std.ArrayList(std.ArrayList(IdType)).init(alloc) };
        }

        pub fn read(alloc: std.mem.Allocator, reader: anytype) !Self {
            // Stack lines in reverse order
            var lines_stack = std.ArrayList([]const u8).init(alloc);
            defer lines_stack.deinit();
            defer {
                for (lines_stack.items) |line| {
                    alloc.free(line);
                }
            }

            while (true) {
                if (try reader.readUntilDelimiterOrEofAlloc(alloc, '\n', 1 << 16)) |line| {
                    try lines_stack.append(line);
                    if (line.len == 0) {
                        _ = lines_stack.pop();
                        break;
                    }
                }
            }

            // Iterate lines in reverse order
            const stacks_count = blk: {
                const label_row = lines_stack.pop();
                const stacks_count = (label_row.len + 1) / 4;
                if (label_row.len % 4 != 3 or stacks_count == 0) {
                    return error.Failure;
                }
                break :blk stacks_count;
            };

            var crate_stacks = try std.ArrayList(std.ArrayList(IdType)).initCapacity(alloc, stacks_count);
            var i: usize = 0;
            while (i < stacks_count) : (i += 1) {
                try crate_stacks.append(std.ArrayList(IdType).init(alloc));
            }
            while (lines_stack.popOrNull()) |line| {
                if (line.len != 4 * stacks_count - 1) {
                    return error.Failure;
                }

                var j: usize = 0;
                for_each_stack: while (j < line.len) : (j += 4) {
                    const index = j / 4;
                    const substr = line[j .. j + 3];

                    for (substr) |char| {
                        if (char != ' ') {
                            break;
                        }
                    } else continue :for_each_stack;

                    if (substr[0] == '[' and substr[2] == ']') {
                        const crate_id = substr[1];
                        try crate_stacks.items[index].append(crate_id);
                        continue :for_each_stack;
                    }

                    return error.Failure;
                }
            }

            return .{ .stacks = crate_stacks };
        }

        pub fn moveCrate(self: Self, from: usize, to: usize) !void {
            var from_stack = &self.stacks.items[from];
            var to_stack = &self.stacks.items[to];
            if (from_stack.popOrNull()) |crate_id| {
                try to_stack.append(crate_id);
            } else {
                return error.Failure;
            }
        }

        pub fn stackTops(self: Self) !std.ArrayList(IdType) {
            var result = std.ArrayList(IdType).init(std.heap.page_allocator);
            for (self.stacks.items) |stack| {
                try result.append(stack.items[stack.items.len - 1]);
            }
            return result;
        }

        pub fn deinit(self: Self) void {
            for (self.stacks.items) |stack| {
                stack.deinit();
            }
            self.stacks.deinit();
        }
    };
}

test "CrateStackInstruction.parse" {
    const str: []const u8 = "move 14 from 4 to 5";

    const calc_result = try CrateStackInstruction.parse(str);
    const expt_result = CrateStackInstruction{ .count = 14, .from_stack = 3, .to_stack = 4 };
    try std.testing.expectEqual(expt_result, calc_result);
}

const CrateStackInstruction = struct {
    const Self = @This();

    count: usize,
    from_stack: usize,
    to_stack: usize,

    pub fn parse(str: []const u8) !Self {
        const str_parts = try splitIntoN(u8, 6, str, &[_]u8{' '});

        for (str_parts[0]) |char, index| {
            if (char != "move"[index]) {
                return error.Failure;
            }
        }
        for (str_parts[2]) |char, index| {
            if (char != "from"[index]) {
                return error.Failure;
            }
        }
        for (str_parts[4]) |char, index| {
            if (char != "to"[index]) {
                return error.Failure;
            }
        }

        return .{
            .count = try std.fmt.parseInt(usize, str_parts[1], 10),
            .from_stack = try std.fmt.parseInt(usize, str_parts[3], 10) - 1,
            .to_stack = try std.fmt.parseInt(usize, str_parts[5], 10) - 1,
        };
    }
};
