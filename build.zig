const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_poma = b.addModule("poma", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib_poma.link_libc = true;
    lib_poma.linkSystemLibrary("pq", .{});

    const lib_tests = b.addTest(.{
        .root_module = lib_poma,
    });

    const run_lib_tests = b.addRunArtifact(lib_tests);

    const test_step = b.step("test", "Run library unit tests");
    test_step.dependOn(&run_lib_tests.step);
}
