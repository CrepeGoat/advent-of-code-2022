const std = @import("std");

test "iterate through file lines - buffer" {
    const buffer_size = 20;
    var stdin = try std.fs.cwd().openFile(
        "src/common/reader_iter_test.txt",
        .{ .mode = std.fs.File.OpenMode.read_only },
    );
    defer stdin.close();

    var iter = readerReadUntilDelimiterOrEofIterator(buffer_size, stdin.reader(), '\n');
    try std.testing.expectEqualSlices(u8, (try iter.next()).?, "testing testing");
    try std.testing.expectEqualSlices(u8, (try iter.next()).?, "1 2 3");
    try std.testing.expectEqual(try iter.next(), null);
}

pub fn readerReadUntilDelimiterOrEofIterator(
    comptime buffer_size: usize,
    reader: anytype,
    delimiter: u8,
) ReaderReadUntilDelimiterOrEofIterator(@TypeOf(reader), buffer_size) {
    return .{ .reader = reader, .buffer = undefined, .delimiter = delimiter };
}

pub fn ReaderReadUntilDelimiterOrEofIterator(comptime ReaderType: type, comptime buffer_size: usize) type {
    return struct {
        const Self = @This();
        reader: ReaderType,
        buffer: [buffer_size]u8,
        delimiter: u8,

        pub fn next(self: Self) !?[]u8 {
            var self_mut = self;
            return self.reader.readUntilDelimiterOrEof(&self_mut.buffer, self.delimiter);
        }
    };
}

test "iterate through file lines - alloc" {
    var stdin = try std.fs.cwd().openFile(
        "src/common/reader_iter_test.txt",
        .{ .mode = std.fs.File.OpenMode.read_only },
    );
    defer stdin.close();

    const alloc = std.testing.allocator;

    var iter = readerReadUntilDelimiterOrEofAllocIterator(alloc, stdin.reader(), '\n', 20);
    var expt_results = .{ "testing testing", "1 2 3" };
    inline for (expt_results) |expt_result| {
        const calc_result = (try iter.next()).?;
        defer alloc.free(calc_result);
        try std.testing.expectEqualSlices(u8, expt_result, calc_result);
    }
    try std.testing.expectEqual(try iter.next(), null);
}

pub fn readerReadUntilDelimiterOrEofAllocIterator(
    alloc: std.mem.Allocator,
    reader: anytype,
    delimiter: u8,
    max_size: usize,
) ReaderReadUntilDelimiterOrEofAllocIterator(@TypeOf(reader)) {
    return .{ .alloc = alloc, .reader = reader, .delimiter = delimiter, .max_size = max_size };
}

pub fn ReaderReadUntilDelimiterOrEofAllocIterator(comptime ReaderType: type) type {
    return struct {
        const Self = @This();
        alloc: std.mem.Allocator,
        reader: ReaderType,
        delimiter: u8,
        max_size: usize,

        pub fn next(self: Self) !?[]u8 {
            var self_mut = self;
            return self.reader.readUntilDelimiterOrEofAlloc(self_mut.alloc, self.delimiter, self.max_size);
        }
    };
}
