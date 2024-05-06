const std = @import("std");
const mem = std.mem;

pub const Token = struct {
    tag: Tag,
    loc: Loc,

    pub const Tag = enum {
        number,
        symbol,
        keyword,
        leftParen,
        rightParen,
        leftSquare,
        rightSquare,
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
        // TODO: I will need a loop here that can take care of
        // multi-line comments and empty lines.
        while (!self.onEOF() and self.onWhitespace()) self.pos += 1;
        if (!self.onEOF() and self.onSemicolon()) self.skipComment();
        if (self.onEOF()) return null;

        const token: Token = switch (self.str[self.pos]) {
            '(', ')', '[', ']' => self.tokenizeBrace(),
            '0'...'9' => self.tokenize(.number),
            '-' => self.tokenizeMinus(),
            ':' => self.tokenize(.keyword),
            else => self.tokenize(.symbol),
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

    fn tokenize(self: *Self, tag: Token.Tag) Token {
        const begin = self.pos;
        while (!self.onEOF() and !self.onWhitespace() and !self.onRightBrace()) self.pos += 1;
        if (self.pos > 0) self.pos -= 1;
        return Token{ .tag = tag, .loc = .{ .begin = begin, .end = self.pos } };
    }

    fn tokenizeBrace(self: *Self) Token {
        const tag: Token.Tag = switch (self.str[self.pos]) {
            '(' => .leftParen,
            ')' => .rightParen,
            '[' => .leftSquare,
            ']' => .rightSquare,
            else => unreachable,
        };
        return .{ .tag = tag, .loc = .{ .begin = self.pos, .end = self.pos } };
    }

    fn tokenizeMinus(self: *Self) Token {
        if (self.str.len > self.pos + 1) {
            switch (self.str[self.pos + 1]) {
                '0'...'9' => return self.tokenize(.number),
                else => return self.tokenize(.symbol),
            }
        }
        return self.tokenize(.symbol);
    }

    fn onWhitespace(self: *Self) bool {
        const chars = [_]u8{ ' ', '\t', '\n', ',' };
        return contains(&chars, self.str[self.pos]);
    }

    fn onRightBrace(self: *Self) bool {
        const chars = [_]u8{ ')', ']', '}' };
        return contains(&chars, self.str[self.pos]);
    }

    fn onEOF(self: *Self) bool {
        return self.pos >= self.str.len;
    }

    fn onNewline(self: *Self) bool {
        return self.str[self.pos] == '\n';
    }

    fn onSemicolon(self: *Self) bool {
        return self.str[self.pos] == ';';
    }

    fn skipComment(self: *Self) void {
        while (!self.onEOF() and !self.onNewline()) self.pos += 1;
    }
};

// test "Tokenizer tests" {
//     var r = Tokenizer{ .str =
//     \\ (123    12  -17 1 143
//     \\ 	(+ 13   (3)))
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

pub const ReadError = error{
    Err,
    UnexpectedEndOfList,
};

pub const Atom = union(enum) {
    number: isize,
    symbol: []const u8,
};

pub const Ast = union(enum) {
    atom: *Atom,
    list: []Ast,
    vector: []Ast,
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
                .leftSquare => return Ast{ .vector = try self.read_list(token) },
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
                // I had the below line initially, however it does not work
                // if the Atom union type has more than one member,
                // giving me the following error:
                // https://github.com/ziglang/zig/issues/19211
                //
                // atom.number = num;
                atom.* = Atom{ .number = num };
                return atom;
            },
            .symbol => {
                atom.* = Atom{ .symbol = buf };
                return atom;
            },
            .keyword => {
                atom.* = Atom{ .symbol = buf };
                return atom;
            },
            else => unreachable,
        }
    }

    fn read_list(self: *Self, token: Token) anyerror![]Ast {
        const until: Token.Tag = switch (token.tag) {
            .leftParen => .rightParen,
            .leftSquare => .rightSquare,
            else => unreachable,
        };

        var list = std.ArrayList(Ast).init(self.alloc);
        while (self.tokenizer.peek()) |t| {
            if (t.tag == until) {
                self.tokenizer.pos += 1;
                return list.toOwnedSlice();
            } else {
                try list.append(try self.read_form());
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
    try expect(result.atom.number == 42);

    // Step 2: a simple list "(1 2 4)"
    const s2 = "(1 2 4)";
    const result2 = try read_str(alloc, s2);
    try expect(result2.list[0].atom.number == 1);
    try expect(result2.list[1].atom.number == 2);
    try expect(result2.list[2].atom.number == 4);

    // Step 3: a nested list "(1 13 (24 47) 8)"
    const s3 = "(1 13 (24 47) 8)";
    const result3 = try read_str(alloc, s3);
    try expect(result3.list[0].atom.number == 1);
    try expect(result3.list[1].atom.number == 13);
    try expect(result3.list[2].list[0].atom.number == 24);
    try expect(result3.list[2].list[1].atom.number == 47);
    try expect(result3.list[3].atom.number == 8);

    // Step 4: nested lists with symbols
    const s4 = "(+ 13 [- 24 47] 8)";
    const plus = "+";
    const copied = try alloc.dupe(u8, plus);
    const result4 = try read_str(alloc, s4);
    try expect(std.mem.eql(u8, copied, result4.list[0].atom.symbol));

    // Step 5: wrong syntax, errors
    const s5 = "(+ 13 ";
    _ = read_str(alloc, s5) catch |err| {
        try expect(err == ReadError.UnexpectedEndOfList);
        return;
    };
}

// Helper functions

/// Check if CHAR is contained in LIST.
fn contains(list: []const u8, char: u8) bool {
    for (list) |item| {
        if (item == char) return true;
    }
    return false;
}
