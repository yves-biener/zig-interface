const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const interface_lib = b.addModule("interface", .{
        .root_source_file = b.path("src/interface.zig"),
    });

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const simple_unit_tests = b.addTest(.{
        .root_source_file = b.path("test/simple.zig"),
        .target = target,
        .optimize = optimize,
    });
    simple_unit_tests.root_module.addImport("interface", interface_lib);
    const run_simple_unit_tests = b.addRunArtifact(simple_unit_tests);

    const complex_unit_tests = b.addTest(.{
        .root_source_file = b.path("test/complex.zig"),
        .target = target,
        .optimize = optimize,
    });
    complex_unit_tests.root_module.addImport("interface", interface_lib);
    const run_complex_unit_tests = b.addRunArtifact(complex_unit_tests);

    const embedded_unit_tests = b.addTest(.{
        .root_source_file = b.path("test/embedded.zig"),
        .target = target,
        .optimize = optimize,
    });
    embedded_unit_tests.root_module.addImport("interface", interface_lib);
    const run_embedded_unit_tests = b.addRunArtifact(embedded_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_simple_unit_tests.step);
    test_step.dependOn(&run_complex_unit_tests.step);
    test_step.dependOn(&run_embedded_unit_tests.step);
}
