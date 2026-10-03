const std = @import("std");
const Build = std.Build;
const Step = std.Build.Step;

pub const ZlibDep = struct {
    lib: *Step.Compile,
    include: Build.LazyPath,
};

pub const Options = struct {
    /// Corresponds to Meson `default_library` (static → `-DSPNG_STATIC`).
    linkage: std.lang.LinkMode = .static,
    /// Meson `enable_opt` (false → `-DSPNG_DISABLE_OPT`).
    enable_opt: bool = true,
    /// Meson auto-detect of GNU `target_clones` (`-DSPNG_ENABLE_TARGET_CLONES`).
    enable_target_clones: bool = false,
    /// Meson `multithreading` feature (`-DSPNG_MULTITHREADING` + pthread).
    multithreading: bool = false,

    pub fn fromBuild(b: *Build) Options {
        const raw_linkage = b.option([]const u8, "linkage", "Library linkage: static or dynamic") orelse "static";
        const linkage: std.lang.LinkMode = blk: {
            if (std.mem.eql(u8, raw_linkage, "static")) break :blk .static;
            if (std.mem.eql(u8, raw_linkage, "dynamic")) break :blk .dynamic;
            std.debug.panic("invalid -Dlinkage value '{s}', expected 'static' or 'dynamic'", .{raw_linkage});
        };

        return .{
            .linkage = linkage,
            .enable_opt = b.option(bool, "enable_opt", "Enable architecture-specific optimizations (Meson enable_opt)") orelse true,
            .enable_target_clones = b.option(
                bool,
                "enable_target_clones",
                "Enable GNU target_clones attribute (Meson compile-check equivalent)",
            ) orelse false,
            .multithreading = b.option(
                bool,
                "multithreading",
                "Experimental multithreading (Meson multithreading, defines SPNG_MULTITHREADING)",
            ) orelse false,
        };
    }
};

pub const Package = struct {
    lib: *Step.Compile,
    module: *Build.Module,
    install: *Step,
};

pub fn configure(
    b: *Build,
    target: Build.ResolvedTarget,
    optimize: std.lang.Optimize,
    libspng: *Build.Dependency,
    zlib: ZlibDep,
    options: Options,
) Package {
    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    // Meson `library('spng')` → libspng.a / spng.lib
    const lib = b.addLibrary(.{
        .name = "spng",
        .linkage = options.linkage,
        .root_module = mod,
    });
    lib.root_module.sanitize_c = .off;

    // Meson: default_library == static → -DSPNG_STATIC
    if (options.linkage == .static) {
        lib.root_module.addCMacro("SPNG_STATIC", "1");
    }

    // Meson: enable_opt == false → -DSPNG_DISABLE_OPT
    //        else + gcc + host x86 → -msse2
    const c_flags: []const []const u8 = if (!options.enable_opt)
        &.{}
    else if (needsSse2Flag(target))
        &.{"-msse2"}
    else
        &.{};

    if (!options.enable_opt) {
        lib.root_module.addCMacro("SPNG_DISABLE_OPT", "1");
    }

    // Meson: cc.links(target_clones) → -DSPNG_ENABLE_TARGET_CLONES
    // The link check fails with the Zig toolchain: clang's target_clones
    // resolver references __cpu_model / __cpu_indicator_init, which come from
    // libgcc and are absent from Zig's compiler-rt on every target (COFF/ELF).
    if (options.enable_target_clones) {
        std.debug.panic(
            "-Denable_target_clones=true is unsupported by the Zig toolchain: " ++
                "target_clones needs libgcc's __cpu_model/__cpu_indicator_init",
            .{},
        );
    }

    // Meson option multithreading (experimental)
    if (options.multithreading) {
        lib.root_module.addCMacro("SPNG_MULTITHREADING", "1");
        if (target.result.os.tag != .windows) {
            lib.root_module.linkSystemLibrary("pthread", .{});
        }
    }

    // Meson: m_dep = cc.find_library('m', required: false)
    if (needsLibm(target)) {
        lib.root_module.linkSystemLibrary("m", .{});
    }

    lib.root_module.addCSourceFile(.{
        .file = libspng.path("spng/spng.c"),
        .flags = c_flags,
    });
    lib.root_module.addIncludePath(libspng.path("spng"));
    lib.root_module.addIncludePath(zlib.include);
    lib.root_module.linkLibrary(zlib.lib);
    lib.installHeader(libspng.path("spng/spng.h"), "spng.h");

    const install = b.addInstallArtifact(lib, .{});

    const translate_c = b.dependency("translate_c", .{});
    const Translator = @import("translate_c").Translator;
    const translator: Translator = .init(translate_c, .{
        .name = "libspng_all",
        .c_source_file = libspngAllHeader(b),
        .target = target,
        .optimize = optimize,
    });
    translator.linkLibrary(lib);
    if (options.linkage == .static) {
        // Match Meson: consumers of the static library need SPNG_STATIC on Windows.
        translator.defineCMacro("SPNG_STATIC", "1");
    }

    // The translator's module is rooted at the generated Zig file and already
    // carries the required `c_builtins` / `helpers` imports and library links.
    _ = b.modules.put(
        b.graph.arena,
        b.graph.dupeString("libspng"),
        translator.mod,
    ) catch @panic("OOM");

    return .{
        .lib = lib,
        .module = translator.mod,
        .install = &install.step,
    };
}

/// Meson: gcc + host_machine.system() == 'x86' → -msse2
fn needsSse2Flag(target: Build.ResolvedTarget) bool {
    return target.result.cpu.arch == .x86;
}

/// Meson: find_library('m', required: false) — typically Unix, not Windows/MSVC.
fn needsLibm(target: Build.ResolvedTarget) bool {
    return switch (target.result.os.tag) {
        .linux, .macos, .freebsd, .openbsd, .netbsd, .dragonfly, .haiku => true,
        else => false,
    };
}

fn libspngAllHeader(b: *Build) Build.LazyPath {
    const build_dir = std.fs.path.dirname(@src().file) orelse unreachable;
    return b.path(b.pathJoin(&.{ build_dir, "..", "include", "libspng_all.h" }));
}
