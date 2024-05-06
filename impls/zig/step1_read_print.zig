const std = @import("std");
const reader = @import("reader.zig");
const printer = @import("printer.zig");

fn READ(alloc: std.mem.Allocator, str: []const u8) !reader.Ast {
    return try reader.read_str(alloc, str);
}

fn EVAL(ast: reader.Ast) reader.Ast {
    return ast;
}

fn PRINT(ast: reader.Ast) !void {
    try printer.pr_str(ast);
}

fn rep(alloc: std.mem.Allocator, str: []const u8) !void {
    const ast = READ(alloc, str) catch |err| {
        try printer.pr_err(err);
        return;
    };
    const evalled_ast = EVAL(ast);
    try PRINT(evalled_ast);
}

pub fn main() !void {
    const stdout = std.io.getStdOut();
    const stdin = std.io.getStdIn().reader();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var line = std.ArrayList(u8).init(alloc);
    defer line.deinit();
    const writer = line.writer();

    try stdout.writeAll("Lispy REPL 0.0.2\n");
    try stdout.writeAll("lisp> ");
    while (stdin.streamUntilDelimiter(writer, '\n', 200)) {
        defer line.clearRetainingCapacity();
        try rep(alloc, line.items);
        try stdout.writeAll("lisp> ");
    } else |err| {
        return err;
    }
}

test "simple test" {}
