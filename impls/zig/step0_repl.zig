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

    try stdout.writeAll("Lispy REPL 0.0.1\n");

    try stdout.writeAll("lisp> ");
    while (stdin.streamUntilDelimiter(writer, '\n', 200)) {
        defer line.clearRetainingCapacity();
        try stdout.writer().print("You said {s}\n", .{line.items});
        try stdout.writeAll("lisp> ");
    } else |err| {
        return err;
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
