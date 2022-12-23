const std = @import("std");

test "iterate through file lines" {
    const buffer_size = 20;
    var stdin = try std.fs.cwd().openFile(
        "src/common/reader_iter_test.txt",
        .{ .mode = std.fs.File.OpenMode.read_only },
    );
    defer stdin.close();

    var iter = readerReadUntilDelimiterOrEofIterator(buffer_size, stdin.reader(), '\n');
    try std.testing.expectEqualSlices(u8, (try iter.next()).?, &[_]u8{ 't', 'e', 's', 't', 'i', 'n', 'g', ' ', 't', 'e', 's', 't', 'i', 'n', 'g' });
    try std.testing.expectEqualSlices(u8, (try iter.next()).?, &[_]u8{ '1', ' ', '2', ' ', '3' });
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
