const std = @import("std");
pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "step1_read_print",
        .root_source_file = .{ .path = "step1_read_print.zig" },
        .target = b.host,
    });
    b.installArtifact(exe);
    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_exe.step);
}
