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

fn parseRoundOutcome(move: u8) !Outcomes {
    return switch (move) {
        'X' => Outcomes.LOSS,
        'Y' => Outcomes.DRAW,
        'Z' => Outcomes.WIN,
        else => error.Failure,
    };
}

fn getMyMove(their_move: RPSMoves, outcome: Outcomes) RPSMoves {
    return @intToEnum(RPSMoves, (2 + @enumToInt(their_move) + @enumToInt(outcome)) % 3);
}

fn getRoundScore(outcome: Outcomes, my_move: RPSMoves) u32 {
    return outcome.score() + my_move.scoreBonus();
}

const RoundStruct = struct { their_move: RPSMoves, outcome: Outcomes };

fn parseRound(str: []const u8) !?RoundStruct {
    if (str.len == 0) {
        return null;
    }
    if (str.len != 3) {
        return error.Failure;
    }

    return .{ .their_move = try parseMoveOpponent(str[0]), .outcome = try parseRoundOutcome(str[2]) };
}

pub fn main(stdin: anytype, stdout: anytype) !void {
    var buffer: [10]u8 = undefined;

    var score: u32 = 0;
    while (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |str| {
        if (try parseRound(str)) |round| {
            const my_move = getMyMove(round.their_move, round.outcome);
            score += getRoundScore(round.outcome, my_move);
        }
    }

    _ = try stdout.write(try std.fmt.bufPrint(&buffer, "{d}\n", .{score}));
}
