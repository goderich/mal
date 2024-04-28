const std = @import("std");
const mem = std.mem;

pub const Token = struct {
    tag: Tag,
    loc: Loc,

    pub const Tag = enum {
        // We'll start small
        number,
        symbol,
        leftParen,
        rightParen,
    };

    pub const Loc = struct {
        begin: usize,
        end: usize,
    };
};

const Tokenizer = struct {
    str: []const u8,
    pos: usize = 0,

    const Self = @This();

    pub fn init(str: []const u8) Tokenizer {
        return Tokenizer{ .str = str };
    }

    pub fn next(self: *Self) ?Token {
        // Fast-forward through whitespace
        // std.debug.print("\nEntering Tokenizer.next at pos {d}\n", .{self.pos});
        while (!self.onEOF() and self.onWhitespace()) self.pos += 1;
        if (self.onEOF()) return null;

        const token: Token = switch (self.str[self.pos]) {
            '(' => .{ .tag = .leftParen, .loc = .{ .begin = self.pos, .end = self.pos } },
            ')' => .{ .tag = .rightParen, .loc = .{ .begin = self.pos, .end = self.pos } },
            // TODO: numbers can be negative
            '0'...'9' => self.tokenizeNum(),
            // TODO: start parsing .symbol
            else => return null,
        };
        self.pos += 1;
        return token;
    }

    pub fn peek(self: *Self) ?Token {
        const old_pos = self.pos;
        const token = self.next();
        self.pos = old_pos;
        return token;
    }

    // When parsing strings >1 char, stop at either a whitespace char
    // or a paren. Right paren only, left paren should be illegal (check).
    fn tokenizeNum(self: *Self) Token {
        const begin = self.pos;
        while (!self.onEOF() and !self.onWhitespace() and !self.onRightParen()) self.pos += 1;
        // TODO: instead of going back here, maybe move differently on each token?
        // OTOH, how do I make sure I don't fly right off the EOF?
        self.pos -= 1;
        return Token{ .tag = .number, .loc = .{ .begin = begin, .end = self.pos } };
    }

    fn onWhitespace(self: *Self) bool {
        const chars = [_]u8{ ' ', '\t', '\n', ',' };
        return contains(&chars, self.str[self.pos]);
    }

    fn onRightParen(self: *Self) bool {
        return self.str[self.pos] == ')';
    }

    fn onEOF(self: *Self) bool {
        return self.pos >= self.str.len;
    }
};

// test "Tokenizer tests" {
//     var r = Tokenizer{
//         .str =
//         \\ (123    12  17 1 143
//         \\ 	( 13   (3)))
//     };
//     std.debug.print("\n", .{});
//     while (true) {
//         if (r.next()) |token| {
//             std.debug.print("{any}\n", .{token});
//         } else break;
//     }
// }

// TODO: test str ending in whitespace, and ending on a paren

//// READER

const ReadError = error{
    Err,
    UnexpectedEndOfList,
};

const Atom = union {
    num: isize,
    // sym:
};

const Ast = union {
    atom: *Atom,
    list: []Ast,
};

pub fn read_str(alloc: mem.Allocator, str: []const u8) !Ast {
    // Instructions:
    // This function will call tokenize and then create a new Reader object instance with the tokens.
    // Then it will call read_form with the Reader instance.

    // Since I don't want to do two passes through the string,
    // I will initialize the Tokenizer inside the Reader.
    // Because we need to allocate the return value in memory and return it,
    // we need to pass an allocator to the fn.

    var reader = Reader.init(alloc, str);
    return reader.read_form();
}

const Reader = struct {
    alloc: mem.Allocator,
    str: []const u8,
    tokenizer: Tokenizer,

    const Self = @This();

    pub fn init(alloc: mem.Allocator, str: []const u8) Reader {
        const t = Tokenizer.init(str);
        return Reader{ .alloc = alloc, .str = str, .tokenizer = t };
    }

    fn read_form(self: *Self) !Ast {
        if (self.tokenizer.next()) |token| {
            switch (token.tag) {
                .leftParen => return Ast{ .list = try self.read_list(token) },
                else => return Ast{ .atom = try self.read_atom(token) },
            }
        } else return ReadError.Err;
    }

    fn read_atom(self: *Self, token: Token) !*Atom {
        const buf = self.str[token.loc.begin .. token.loc.end + 1];
        const atom = try self.alloc.create(Atom);
        switch (token.tag) {
            .number => {
                const num = try std.fmt.parseInt(isize, buf, 10);
                atom.num = num;
                return atom;
            },
            else => unreachable,
        }
    }

    fn read_list(self: *Self, token: Token) anyerror![]Ast {
        const until = switch (token.tag) {
            .leftParen => .rightParen,
            else => return ReadError.Err,
        };

        var list = std.ArrayList(Ast).init(self.alloc);
        while (self.tokenizer.peek()) |t| {
            switch (t.tag) {
                until => return list.toOwnedSlice(),
                else => try list.append(try self.read_form()),
            }
        }
        return ReadError.UnexpectedEndOfList;
    }
};

test "Reader" {
    const expect = std.testing.expect;

    // Using an arena in tests to free all memory at once.
    // In actual usage, the caller will own (and free) the memory,
    // possibly using a very similar approach.
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    // Step 1: a single int "42"
    const s = "   42   ";
    const result = try read_str(alloc, s);
    try expect(result.atom.num == 42);

    // Step 2: a simple list "(1 2 4)"
    const s2 = "(1 2 4)";
    const result2 = try read_str(alloc, s2);
    try expect(result2.list[0].atom.num == 1);
    try expect(result2.list[1].atom.num == 2);
    try expect(result2.list[2].atom.num == 4);

    // Step 3: a nested list "(1 13 (24 47) 8)"
    // Step 4: nested lists with symbols
    // Step 5: wrong syntax, errors
}

// Helper functions

/// Check if CHAR is contained in LIST.
fn contains(list: []const u8, char: u8) bool {
    for (list) |item| {
        if (item == char) return true;
    }
    return false;
}
