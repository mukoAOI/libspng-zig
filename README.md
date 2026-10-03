# libspng

## 要求

- Zig 0.17.0 或更高版本
- 需要 zlib：由 [zlib_build](https://github.com/mukoAOI/zlib) 0.2.0 作为传递依赖自动提供
- Zig 绑定（`libspng.module("libspng")`）由官方 [translate-c](https://codeberg.org/ziglang/translate-c) 包（2.0.0，对应 Zig 0.17.x）在构建时生成，同样是传递依赖，消费方无需声明

## 作为依赖使用

在 `build.zig.zon` 中添加（也可用 `zig fetch --save git+https://github.com/mukoAOI/libspng-zig#0.2.0` 自动写入）：

```zon
.dependencies = .{
    .libspng = .{
        .url = "git+https://github.com/mukoAOI/libspng-zig?ref=0.2.0#21b539e76f654a4bc1e955b76ab09f3a8a910881",
        .hash = "libspng-0.1.0-Q9gapQ4rAAAQrREvzNFmvrguuzmlTv2iGCt5a1cHEmD4",
    },
},
```

在 `build.zig` 中（zlib 后端等选项会透传给内部的 zlib_build）：

```zig
const libspng = b.dependency("libspng", .{
    .target = target,
    .optimize = optimize,
    .linkage = "static", // 或 "dynamic"
    .zlib = "zlib-ng", // zlib / zlib-ng
    .simd_level = "max", // generic / sse2 / avx2 / avx512 / max
    .runtime_cpu_detection = true,
    .enable_opt = true,
    // .multithreading = false,
});
const spng = libspng.artifact("spng"); // Meson library('spng') → libspng.a
// Zig 模块：libspng.module("libspng")
```

## 配置选项（对应 Meson）

| Zig `-D` | 默认 | Meson | 效果 |
|----------|------|-------|------|
| `linkage` | `static` | `default_library` | 静态库定义 `SPNG_STATIC` |
| `enable_opt` | `true` | `enable_opt` | `false` → `SPNG_DISABLE_OPT`；x86 开启时加 `-msse2` |
| `enable_target_clones` | `false` | `cc.links(target_clones)` | **Zig 工具链不支持**：clang 的 resolver 依赖 libgcc 的 `__cpu_model`/`__cpu_indicator_init`，编译器自带的 compiler-rt 不提供；设为 `true` 会直接报错（Meson 的链接检测会将其判定为不可用） |
| `multithreading` | `false` | `multithreading` | 定义 `SPNG_MULTITHREADING`（非 Windows 链 pthread） |
| `zlib` | `zlib-ng` | `static_zlib` 等 | 透传给 zlib_build 的后端选择 |
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
zig build -Dmultithreading=true              # 实验性多线程
```

## 许可证

本仓库仅为构建脚本；libspng 源码遵循其上游许可证。
