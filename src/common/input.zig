const std = @import("std");

pub fn ReaderReadUntilDelimiterOrEofIterator(comptime ReaderType: type) type {
    return struct {
        const This = @This();
        reader: ReaderType,
        buffer: []u8,
        delimiter: u8,

        pub fn next(this: *This) !?[]u8 {
            return this.reader.readUntilDelimiterOrEof(this.buffer, this.delimiter);
        }
    };
}

pub fn readerReadUntilDelimiterOrEofIterator(
    reader: anytype,
    buffer: []u8,
    delimiter: u8,
) ReaderReadUntilDelimiterOrEofIterator(@TypeOf(reader)) {
    return .{ .reader = reader, .buffer = buffer, .delimiter = delimiter };
}
