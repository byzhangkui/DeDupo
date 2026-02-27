# DeDupo 构建指南

本文档面向新手，从零开始介绍如何搭建开发环境、编译并运行 DeDupo。

---

## 目录

1. [系统要求](#1-系统要求)
2. [安装前置工具](#2-安装前置工具)
3. [验证 Rust 核心编译](#3-验证-rust-核心编译)
4. [生成 Xcode 项目](#4-生成-xcode-项目)
5. [在 Xcode 中构建运行](#5-在-xcode-中构建运行)
6. [打包分发 (DMG)](#6-打包分发-dmg)
7. [常见问题](#7-常见问题)

---

## 1. 系统要求

| 项目 | 最低版本 |
|------|----------|
| macOS | 15.0 (Sequoia) |
| Xcode | 16.0+ |
| Rust | 1.75+ (stable) |
| XcodeGen | 2.38+ |

---

## 2. 安装前置工具

### 2.1 Xcode & Command Line Tools

从 App Store 安装 Xcode 16+，然后在终端运行：

```bash
xcode-select --install
```

### 2.2 Rust 工具链

```bash
# 安装 Rust（按提示选默认即可）
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 加载环境变量（或重启终端）
source ~/.cargo/env

# 验证安装
rustc --version   # 应显示 rustc 1.75.0 或更高
cargo --version
```

### 2.3 添加 macOS 编译目标

根据你的 Mac 芯片选择：

```bash
# Apple Silicon (M1/M2/M3/M4)
rustup target add aarch64-apple-darwin

# Intel Mac
rustup target add x86_64-apple-darwin

# 两个都装也可以（用于 Universal Binary）
```

### 2.4 安装 cbindgen

cbindgen 用于从 Rust 代码自动生成 C 头文件，供 Swift 调用：

```bash
cargo install cbindgen
```

### 2.5 安装 XcodeGen

XcodeGen 从 `project.yml` 配置文件自动生成 `.xcodeproj`：

```bash
# 推荐用 Homebrew 安装
brew install xcodegen

# 验证
xcodegen --version
```

---

## 3. 验证 Rust 核心编译

在进入 Xcode 之前，先确认 Rust 侧能正常编译：

```bash
cd DeDupo/dedupo-core

# 编译
cargo build

# 运行单元测试
cargo test
```

预期输出：

```
   Compiling dedupo-core v0.1.0
    Finished dev [unoptimized + debuginfo] target(s)

running 5 tests
test hasher::blake3_hash::tests::test_hash_consistency ... ok
test hasher::blake3_hash::tests::test_different_content_different_hash ... ok
test hasher::blake3_hash::tests::test_head_hash_small_file ... ok
test dedup::grouper::tests::test_group_by_size_eliminates_unique ... ok
test dedup::grouper::tests::test_build_duplicate_groups_keeps_oldest ... ok
```

如果这一步失败，请先解决 Rust 环境问题再继续。

---

## 4. 生成 Xcode 项目

项目使用 **XcodeGen** 管理 Xcode 项目文件，避免手动配置。

```bash
# 回到仓库根目录
cd DeDupo

# 生成 .xcodeproj
xcodegen generate
```

成功后会看到：

```
⚙️  Generating plists...
⚙️  Generating project...
⚙️  Writing project...
Created project at DeDupo.xcodeproj
```

> **注意：** 生成的 `DeDupo.xcodeproj` 已在 `.gitignore` 中，不需要提交到 Git。
> 每个开发者克隆仓库后运行一次 `xcodegen generate` 即可。

---

## 5. 在 Xcode 中构建运行

### 5.1 打开项目

```bash
open DeDupo.xcodeproj
```

或者在 Xcode 中 File → Open → 选择 `DeDupo.xcodeproj`。

### 5.2 构建运行

1. 在 Xcode 顶部确认 Scheme 选择 **DeDupo** → **My Mac**
2. 按 **⌘ + R**（Cmd + R）构建并运行

Xcode 会自动执行以下流程：

```
Pre-build Script (Build Rust Core)
    ↓  cargo build → libdedupo_core.a
    ↓  cbindgen → dedupo_ffi.h
Compile Swift Sources
    ↓
Link Binary (libdedupo_core.a + 系统库)
    ↓
DeDupo.app 启动
```

### 5.3 首次构建说明

- **首次编译较慢**：Rust 需要下载和编译所有依赖（blake3, walkdir, rayon 等），可能需要 2-5 分钟
- **后续编译很快**：Rust 增量编译 + Swift 增量编译，通常几秒内完成
- 如果出现权限弹窗，允许 DeDupo 访问文件系统

---

## 6. 打包分发 (DMG)

### 6.1 Release 构建

在 Xcode 中：Product → Archive，或命令行：

```bash
xcodebuild -project DeDupo.xcodeproj \
    -scheme DeDupo \
    -configuration Release \
    -archivePath build/DeDupo.xcarchive \
    archive
```

### 6.2 生成 DMG

```bash
./scripts/package-dmg.sh build/Release/DeDupo.app
```

生成的 DMG 文件位于 `dist/DeDupo-0.1.0.dmg`。

---

## 7. 常见问题

### Q: `cargo build` 报错 "linker not found"

安装 Xcode Command Line Tools：

```bash
xcode-select --install
```

### Q: Xcode 报 "No such module" 或找不到头文件

确认 Bridging Header 设置正确：

1. Xcode → Build Settings → 搜索 "Bridging Header"
2. 值应为：`DeDupo/Bridge/dedupo_ffi.h`

如果用 XcodeGen 生成项目，这个已经自动配置好了。

### Q: 链接错误 "Undefined symbols: _dedupo_*"

Rust 库没有编译或没有链接上：

```bash
# 手动编译 Rust 库
cd dedupo-core
cargo build --target aarch64-apple-darwin  # 或 x86_64-apple-darwin

# 确认静态库存在
ls -la target/aarch64-apple-darwin/debug/libdedupo_core.a
```

然后在 Xcode 的 Library Search Paths 中添加对应路径。

### Q: `xcodegen generate` 报错

确认你在仓库根目录（包含 `project.yml` 的目录）运行命令：

```bash
ls project.yml   # 应该能看到这个文件
xcodegen generate
```

### Q: 如何切换 Debug / Release 模式

- Xcode 中：Product → Scheme → Edit Scheme → Run → Build Configuration
- Debug: Rust 不优化，编译快，体积大
- Release: Rust 全优化，编译慢，性能好

### Q: 如何编译 Universal Binary（同时支持 Intel + Apple Silicon）

```bash
cd dedupo-core
cargo build --release --target aarch64-apple-darwin
cargo build --release --target x86_64-apple-darwin

lipo -create \
    target/aarch64-apple-darwin/release/libdedupo_core.a \
    target/x86_64-apple-darwin/release/libdedupo_core.a \
    -output libdedupo_core_universal.a
```

---

## 快速参考

```bash
# 一键设置（首次克隆仓库后执行）
cargo install cbindgen              # 安装 cbindgen
brew install xcodegen               # 安装 XcodeGen
cd dedupo-core && cargo build && cd ..  # 编译 Rust
xcodegen generate                   # 生成 Xcode 项目
open DeDupo.xcodeproj               # 打开 Xcode
# 然后按 ⌘+R 运行
```
