# libspng

用 Zig 构建系统编译 [libspng](https://github.com/randy408/libspng) v0.7.4，并提供 translateC 模块。

选项对齐上游 Meson（`meson.build` / `meson_options.txt` 中影响库本身的部分）。

## 要求

- Zig 0.16.0 或更高版本
- 需要链接 zlib（通过 `zlib_build` 包提供）

## 作为依赖使用

在 `build.zig.zon` 中添加 `libspng` 与 `zlib_build`，在 `build.zig` 中：

```zig
const zlib_build = b.dependency("zlib_build", .{
    .target = target,
    .optimize = optimize,
    .backend = "zlib-ng", // 默认 "zlib-ng"，可改 "zlib"
    .simd_level = "max", // generic / sse2 / avx2 / avx512 / max
    .runtime_cpu_detection = true,
});
const z = zlib_build.artifact("z");

const libspng = b.dependency("libspng", .{
    .target = target,
    .optimize = optimize,
    .linkage = "static", // 或 "dynamic"
    .enable_opt = true,
    .enable_target_clones = false,
    .multithreading = false,
});
const spng = libspng.artifact("spng"); // Meson library('spng') → libspng.a
// Zig 模块：libspng.module("libspng")
```

## 配置选项（对应 Meson）

| Zig `-D` | 默认 | Meson | 效果 |
|----------|------|-------|------|
| `linkage` | `static` | `default_library` | 静态库定义 `SPNG_STATIC` |
| `enable_opt` | `true` | `enable_opt` | `false` → `SPNG_DISABLE_OPT`；x86 开启时加 `-msse2` |
| `enable_target_clones` | `false` | `cc.links(target_clones)` | 定义 `SPNG_ENABLE_TARGET_CLONES` |
| `multithreading` | `false` | `multithreading` | 定义 `SPNG_MULTITHREADING`（非 Windows 链 pthread） |
| （自动） | — | `find_library('m')` | Linux/BSD/macOS 链接 `libm` |

未移植（测例 / 示例 / 未接入的压缩后端）：`dev_build`、`benchmarks`、`build_examples`、`use_miniz`、`oss_fuzz`。zlib 静态/动态由 `zlib_build` 的 `linkage` 控制，对应 Meson `static_zlib`。

## 本地开发

```powershell
zig build                                    # 默认 zlib-ng + SIMD（runtime 检测）
zig build -Dzlib=zlib                        # stock zlib
zig build -Dsimd_level=avx2                  # zlib-ng，不含 AVX512
zig build -Druntime_cpu_detection=false      # zlib-ng，仅 generic C
zig build -Denable_opt=false                 # 关闭 libspng 架构优化
zig build -Dlinkage=dynamic                  # 构建动态库
```

## 许可证

本仓库仅为构建脚本；libspng 源码遵循其上游许可证。
