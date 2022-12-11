const std = @import("std");

pub fn IteratorInterface(comptime T: type) type {
    return struct {
        const This = @This();

        next: fn (*This) ?T,
    };
}

pub fn RangeIterator(comptime NumberType: type, comptime SizeType: type) type {
    return struct {
        const This = @This();
        const Item = NumberType;

        start: NumberType,
        step: NumberType,
        len: SizeType,
        _index: SizeType = 0,

        fn next(this: *This) !?Item {
            if (this._index >= this.len) {
                return null;
            }
            defer this._index += 1;
            return this.start + (this.step * @intCast(NumberType, this._index));
        }
    };
}

test "range iterator" {
    var iterator = RangeIterator(u32, u32){ .start = 1, .step = 3, .len = 5 };

    try std.testing.expectEqual(iterator.next(), 1);
    try std.testing.expectEqual(iterator.next(), 4);
    try std.testing.expectEqual(iterator.next(), 7);
    try std.testing.expectEqual(iterator.next(), 10);
    try std.testing.expectEqual(iterator.next(), 13);
    try std.testing.expectEqual(iterator.next(), null);
}

// based on pattern used for BufferedWriter & bufferedWriter
// https://github.com/ziglang/zig/blob/master/lib/std/io/buffered_writer.zig

pub fn IterWhile(
    comptime IteratorType: type,
    comptime ItemType: type,
    comptime include_last: bool,
) type {
    return struct {
        const This = @This();
        const Item = ItemType;

        iterator: IteratorType,
        predicate: fn (ItemType) bool,
        _is_spent: bool = false,

        pub fn next(this: *This) ?ItemType {
            if (this._is_spent) {
                return null;
            }

            const result = try this.iterator.next();
            if (result == null) {
                return null;
            }
            if (!this.predicate(result)) {
                this._is_spent = true;
                if (!include_last) return null;
            }
            return result;
        }
    };
}

pub fn iterWhile(
    iterator: anytype,
    predicate: fn (anytype) bool,
    comptime include_last: bool,
) IterWhile(
    @TypeOf(iterator),
    @typeInfo(predicate).Fn.args[0].arg_type,
    include_last,
) {
    return .{ .iterator = iterator, .predicate = predicate };
}

test "iter while" {
    const NumberType = i32;
    var range = RangeIterator(NumberType, NumberType){ .start = 1, .step = 3, .len = 5 };
    var iterator = iterWhile(range, TestUtils(NumberType).isOneDigit, false);

    try std.testing.expectEqual(iterator.next(), 1);
    try std.testing.expectEqual(iterator.next(), 4);
    try std.testing.expectEqual(iterator.next(), 7);
    try std.testing.expectEqual(iterator.next(), null);
}

pub fn IterFilter(comptime IteratorType: type, ItemType: type) type {
    return struct {
        const This = @This();
        const Item = ItemType;

        iterator: IteratorType,
        predicate: fn (ItemType) bool,

        pub fn next(this: *This) ?ItemType {
            return while (try this.iterator.next()) |value| {
                if (this.predicate(value)) {
                    break value;
                }
            } else null;
        }
    };
}

pub fn iterFilter(
    iterator: anytype,
    predicate: fn (anytype) bool,
) IterFilter(@TypeOf(iterator), @typeInfo(@TypeOf(predicate)).args[0].arg_type) {
    return .{ .iterator = iterator, .predicate = predicate };
}

pub fn IterMap(
    comptime IteratorType: type,
    comptime ItemInType: type,
    comptime ItemOutType: type,
) type {
    return struct {
        const This = @This();
        const Item = ItemOutType;

        iterator: IteratorType,
        map: fn (ItemInType) ItemOutType,

        pub fn next(this: *This) ?ItemOutType {
            return if (try this.iterator.next()) |value| this.map(value) else null;
        }
    };
}

pub fn iterMap(
    iterator: anytype,
    map: anytype,
) IterMap(
    @TypeOf(iterator),
    @typeInfo(map).Fn.args[0].arg_type,
    @typeInfo(map).Fn.return_type,
) {
    return .{ .iterator = iterator, .map = map };
}

pub fn iterFold(
    iterator: anytype,
    init: anytype,
    fold: fn (@TypeOf(init), anytype) @TypeOf(init),
) @TypeOf(init) {
    var init_mut: @TypeOf(init) = init;

    while (try iterator.next()) |value| {
        init_mut = fold(init_mut, value);
    }

    return init_mut;
}

pub fn IterGroupWhile(
    comptime IteratorType: type,
    comptime ItemType: type,
    comptime include_last: bool,
) type {
    return struct {
        const This = @This();
        const Item = ItemType;

        iterator: IteratorType,
        predicate: fn (ItemType) bool,
        inner_emit_count: usize = 0,
        inner_index: usize = 0,
        is_spent: bool = false,

        const InnerIterator = struct {
            const InnerThis = @This();
            outer: *This,
            outer_index: usize,
            is_spent: bool = false,

            pub fn next(this: *InnerThis) !?ItemType {
                if (this.inner_index != this.outer.inner_index) {
                    return error.Failure;
                }
                const maybe_item = try this.outer.iterator.next();
                if (!maybe_item) {
                    this.outer.is_spent = true;
                    return null;
                } else |item| {
                    if (!this.outer.predicate(item)) {
                        this.is_spent = true;
                        this.outer.inner_index += 1;
                        if (!include_last) return null;
                    }
                    return item;
                }
            }
        };

        pub fn next(this: *This) ?InnerIterator {
            if (!this.is_spent) {
                return null;
            }

            defer this.inner_emit_count += 1;
            return InnerIterator{ .outer = this, .outer_index = this.inner_emit_count };
        }
    };
}

pub fn iterGroupWhile(
    iterator: anytype,
    predicate: fn (anytype) bool,
    comptime include_last: bool,
) IterGroupWhile(
    @TypeOf(iterator),
    @typeInfo(@TypeOf(predicate)).args[0].arg_type,
    include_last,
) {
    return .{ .iterator = iterator, .predicate = predicate };
}

fn TestUtils(comptime NumType: type) type {
    return struct {
        fn double(value: NumType) NumType {
            return 2 * value;
        }
        fn isOneDigit(value: NumType) bool {
            return value < 10;
        }
    };
}
