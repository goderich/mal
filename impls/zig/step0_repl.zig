const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut();
    const stdin = std.io.getStdIn().reader();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var line = std.ArrayList(u8).init(alloc);
    defer line.deinit();
    const writer = line.writer();

    try stdout.writeAll("Lispy REPL 0.0.0\n");
    try stdout.writeAll("lisp> ");
    while (stdin.streamUntilDelimiter(writer, '\n', 200)) {
        defer line.clearRetainingCapacity();
        try stdout.writer().print("You said {s}\n", .{line.items});
        try stdout.writeAll("lisp> ");
    } else |err| {
        return err;
    }
}
