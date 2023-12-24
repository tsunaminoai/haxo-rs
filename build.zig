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

    const cPeriphery = b.addStaticLibrary(.{
        .name = "cPeriphery",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .target = target,
        .optimize = optimize,
    });
    cPeriphery.addCSourceFiles(.{
        .files = c_files,
        .flags = &.{
            "-O3",
            "-fPIC",
            "-g",
            "-Wall",
            "-Werror",
            "-std=gnu99",
            "-pedantic",
            // "-Wno-stringop-truncation",
        },
    });
    cPeriphery.linkLibC();
    cPeriphery.addIncludePath(.{ .path = "../../c/c-periphery/src" });
    cPeriphery.addSystemIncludePath(.{ .path = "../../c/linux/include" });
    cPeriphery.addSystemIncludePath(.{ .path = "../../c/mac-linux-headers" });
    b.installArtifact(cPeriphery);

    const zigpio = b.addModule("zigpio", .{
        .source_file = .{ .path = "zigpio/src/gpio.zig" },
    });

    const exe = b.addExecutable(.{
        .name = "haxo-rs",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.addSystemIncludePath(.{ .path = "/opt/homebrew/include" });
    exe.linkSystemLibrary("fluidsynth");
    exe.addModule("zigpio", zigpio);
    // exe.linkLibrary(i2c);

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/root.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    const audio_options = b.addOptions();
    audio_options.addOption([]const u8, "audio_driver", switch (target.getOsTag()) {
        .linux => "alsa",
        .macos => "portaudio",
        else => "coreaudio",
    });
    exe.addOptions("audio", audio_options);
    exe_unit_tests.linkSystemLibrary("fluidsynth");
    exe_unit_tests.addOptions("audio", audio_options);
    exe_unit_tests.addModule("zigpio", zigpio);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}

const c_files = &.{
    "../../c/c-periphery/src/gpio.c",
    "../../c/c-periphery/src/gpio_cdev_v1.c",
    "../../c/c-periphery/src/gpio_cdev_v2.c",
    "../../c/c-periphery/src/gpio_sysfs.c",
    "../../c/c-periphery/src/i2c.c",
    "../../c/c-periphery/src/led.c",
    "../../c/c-periphery/src/mmio.c",
    "../../c/c-periphery/src/pwm.c",
    "../../c/c-periphery/src/serial.c",
    "../../c/c-periphery/src/spi.c",
    "../../c/c-periphery/src/version.c",
};
