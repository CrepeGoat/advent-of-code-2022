const std = @import("std");

const RPSMoves = enum(u32) {
    ROCK = 0,
    PAPER = 1,
    SCISSORS = 2,

    pub fn scoreBonus(self: RPSMoves) u32 {
        return @enumToInt(self) + 1;
    }
};

const Outcomes = enum(u32) {
    LOSS = 0,
    DRAW = 1,
    WIN = 2,

    pub fn score(self: Outcomes) u32 {
        return @enumToInt(self) * 3;
    }
};

fn parseMoveOpponent(move: u8) !RPSMoves {
    return switch (move) {
        'A' => RPSMoves.ROCK,
        'B' => RPSMoves.PAPER,
        'C' => RPSMoves.SCISSORS,
        else => error.Failure,
    };
}

fn parseMoveMine(move: u8) !RPSMoves {
    return switch (move) {
        'X' => RPSMoves.ROCK,
        'Y' => RPSMoves.PAPER,
        'Z' => RPSMoves.SCISSORS,
        else => error.Failure,
    };
}

fn getRoundOutcome(their_move: RPSMoves, my_move: RPSMoves) Outcomes {
    return @intToEnum(Outcomes, (4 + @enumToInt(my_move) - @enumToInt(their_move)) % 3);
}

fn getRoundScore(their_move: RPSMoves, my_move: RPSMoves) u32 {
    return getRoundOutcome(their_move, my_move).score() + my_move.scoreBonus();
}

fn parseRound(str: []const u8) !?[2]RPSMoves {
    if (str.len == 0) {
        return null;
    }
    if (str.len != 3) {
        return error.Failure;
    }

    return .{ try parseMoveOpponent(str[0]), try parseMoveMine(str[2]) };
}

pub fn main(stdin: anytype, stdout: anytype) !void {
    var buffer: [10]u8 = undefined;

    var score: u32 = 0;
    while (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |str| {
        if (try parseRound(str)) |moves| {
            const their_move = moves[0];
            const my_move = moves[1];
            score += getRoundScore(their_move, my_move);
        }
    }

    _ = try stdout.write(try std.fmt.bufPrint(&buffer, "{d}\n", .{score}));
}
