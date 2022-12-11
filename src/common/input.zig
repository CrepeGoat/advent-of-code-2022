const std = @import("std");
const iter_tools = @import("../utils/iterator.zig");

pub fn ReaderReadUntilDelimiterOrEofIterator(comptime ReaderType: type) type {
    return struct {
        const Self = @This();
        reader: ReaderType,
        buffer: []u8,
        delimiter: u8,

        pub fn next(self: Self) !?[]u8 {
            return self.reader.readUntilDelimiterOrEof(self.buffer, self.delimiter);
        }

        usingnamespace iter_tools.Functions;
    };
}

pub fn readerReadUntilDelimiterOrEofIterator(
    reader: anytype,
    buffer: []u8,
    delimiter: u8,
) ReaderReadUntilDelimiterOrEofIterator(@TypeOf(reader)) {
    return .{ .reader = reader, .buffer = buffer, .delimiter = delimiter };
}
