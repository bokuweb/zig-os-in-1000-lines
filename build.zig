const std = @import("std");
const Builder = @import("std").build.Builder;
const Step = @import("std").build.Step;
const CompileStep = @import("std").build.CompileStep;
const Target = @import("std").Target;

pub fn build(b: *Builder) void {
    if (b.args) |args| {
        if (std.mem.eql(u8, args[0], "--user")) {
            const Feature = @import("std").Target.Cpu.Feature;
            const features = Target.riscv.Feature;
            const double_float: std.Target.riscv.Feature = .d;
            _ = double_float;
            var disabled_features = Feature.Set.empty;
            var enabled_features = Feature.Set.empty;

            disabled_features.addFeature(@intFromEnum(features.a));
            disabled_features.addFeature(@intFromEnum(features.d));
            disabled_features.addFeature(@intFromEnum(features.e));
            disabled_features.addFeature(@intFromEnum(features.f));
            disabled_features.addFeature(@intFromEnum(features.c));
            enabled_features.addFeature(@intFromEnum(features.m));

            const target = std.zig.CrossTarget{ .os_tag = .freestanding, .cpu_arch = .riscv32, .abi = Target.Abi.none, .ofmt = .elf, .cpu_features_sub = disabled_features, .cpu_features_add = enabled_features };
            const exe = b.addExecutable(std.Build.ExecutableOptions{ .name = "user", .root_source_file = std.build.LazyPath.relative("./src/user.zig") });
            exe.target = target;
            exe.setLinkerScript(std.build.LazyPath.relative("./user.ld"));
            exe.addIncludePath(std.build.LazyPath.relative("./src"));
            exe.addCSourceFiles(&.{ "src/common.c", "src/user.c" }, &.{
                "-std=c11",
                "-Wall",
            });
            b.installArtifact(exe);
            return;
        }
    }

    _ = b.exec(&[_][]const u8{
        "zig",
        "build",
        "--",
        "--user",
    });

    const Feature = @import("std").Target.Cpu.Feature;
    const features = Target.riscv.Feature;
    const double_float: std.Target.riscv.Feature = .d;
    _ = double_float;
    var disabled_features = Feature.Set.empty;
    var enabled_features = Feature.Set.empty;

    disabled_features.addFeature(@intFromEnum(features.a));
    disabled_features.addFeature(@intFromEnum(features.d));
    disabled_features.addFeature(@intFromEnum(features.e));
    disabled_features.addFeature(@intFromEnum(features.f));
    disabled_features.addFeature(@intFromEnum(features.c));
    enabled_features.addFeature(@intFromEnum(features.m));

    const target = std.zig.CrossTarget{ .os_tag = .freestanding, .cpu_arch = .riscv32, .abi = Target.Abi.none, .ofmt = .elf, .cpu_features_sub = disabled_features, .cpu_features_add = enabled_features };
    const exe = b.addExecutable(std.Build.ExecutableOptions{ .name = "kernel", .root_source_file = std.build.LazyPath.relative("./src/main.zig") });

    exe.target = target;
    exe.setLinkerScript(std.build.LazyPath.relative("./kernel.ld"));

    exe.addIncludePath(std.build.LazyPath.relative("./src"));
    exe.addCSourceFiles(&.{ "src/common.c", "src/kernel.c" }, &.{
        "-std=c11",
        "-Wall",
    });

    _ = b.exec(&[_][]const u8{
        "llvm-objcopy",
        "--set-section-flags",
        ".bss=alloc,contents",
        "-O",
        "binary",
        "zig-out/bin/user",
        "user.bin",
    });

    _ = b.exec(&[_][]const u8{
        "llvm-objcopy",
        "-Ibinary",
        "-Oelf32-littleriscv",
        "user.bin",
        "user.bin.o",
    });

    exe.addObjectFile(std.build.LazyPath.relative("./user.bin.o"));
    b.installArtifact(exe);
}

pub fn main() void {
    @import("std").build.run(build, @import("std").builtin.Builder);
}
