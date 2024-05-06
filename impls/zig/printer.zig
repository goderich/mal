const std = @import("std");
const reader = @import("reader.zig");
const stdout = std.io.getStdOut();

pub fn pr_str(ast: reader.Ast) !void {
    try pr_ast(ast);
    try stdout.writeAll("\n");
}

fn pr_ast(ast: reader.Ast) anyerror!void {
    switch (ast) {
        .atom => try pr_atom(ast.atom),
        .list => try pr_list(ast),
        .vector => try pr_vector(ast),
    }
}

fn pr_atom(atom: *reader.Atom) !void {
    switch (atom.*) {
        .number => try stdout.writer().print("{d}", .{atom.number}),
        .symbol => try stdout.writer().print("{s}", .{atom.symbol}),
        .keyword => try stdout.writer().print("{s}", .{atom.keyword}),
    }
}

fn pr_list(ast: reader.Ast) !void {
    try stdout.writeAll("(");
    var i: usize = 0;
    while (i < ast.list.len) : (i += 1) {
        try pr_ast(ast.list[i]);
        if (i < ast.list.len - 1) try stdout.writeAll(" ");
    }
    try stdout.writeAll(")");
}

fn pr_vector(ast: reader.Ast) !void {
    try stdout.writeAll("[");
    var i: usize = 0;
    while (i < ast.list.len) : (i += 1) {
        try pr_ast(ast.list[i]);
        if (i < ast.list.len - 1) try stdout.writeAll(" ");
    }
    try stdout.writeAll("]");
}

pub fn pr_err(err: anyerror) !void {
    switch (err) {
        reader.ReadError.UnexpectedEndOfList => try stdout.writeAll("Error: unbalanced parentheses.\n"),
        else => try stdout.writeAll("Error: general error."),
    }
}

test "print" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const str1 = "     143   ";
    const result1 = try reader.read_str(alloc, str1);
    try pr_str(result1);

    const str2 =
        \\ (+ 123    12  -17 1 143
        \\ 	(- 13   (+  3))
        \\ )
    ;
    const result2 = try reader.read_str(alloc, str2);
    try pr_str(result2);
}
