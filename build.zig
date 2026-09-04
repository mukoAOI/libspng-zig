const std = @import("std");
const pkg = @import("build/package.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const options = pkg.Options.fromBuild(b);

    const libspng = b.dependency("libspng", .{
        .target = target,
        .optimize = optimize,
    });
    const zlib_build = b.dependency("zlib_build", .{
        .target = target,
        .optimize = optimize,
        .backend = b.option([]const u8, "zlib", "Zlib backend: zlib or zlib-ng") orelse "zlib-ng",
        .simd_level = b.option([]const u8, "simd_level", "Max x86 SIMD tier: generic, sse2, avx2, avx512, max") orelse "max",
        .runtime_cpu_detection = b.option(bool, "runtime_cpu_detection", "Enable runtime CPU feature detection (zlib-ng)") orelse true,
    });
    const z = zlib_build.artifact("z");

    const configured = pkg.configure(b, target, optimize, libspng, .{
        .lib = z,
        .include = z.getEmittedIncludeTree(),
    }, options);
    b.getInstallStep().dependOn(&b.addInstallArtifact(configured.lib, .{}).step);
    _ = configured.module;
}
