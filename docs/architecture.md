# DeDupo — 架构设计文档

## 1. 项目概览

| 项目 | 说明 |
|------|------|
| **名称** | DeDupo |
| **定位** | macOS 原生文件去重工具 |
| **技术架构** | SwiftUI (UI) + Rust Core (引擎) |
| **最低系统** | macOS 15 (Sequoia) |
| **分发方式** | DMG 直接分发 + Sparkle 自动更新 |
| **目标平台** | Mac 优先，Rust Core 可复用于未来 Windows 端 |

---

## 2. 系统架构

```
┌─────────────────────────────────────────────────────┐
│                    DeDupo.app                        │
│                                                     │
│  ┌───────────────────────────────────────────────┐  │
│  │              SwiftUI Layer                     │  │
│  │                                               │  │
│  │  ┌─────────┐ ┌──────────┐ ┌───────────────┐  │  │
│  │  │ Scanner │ │ Results  │ │   Settings    │  │  │
│  │  │  View   │ │  View    │ │     View      │  │  │
│  │  └─────────┘ └──────────┘ └───────────────┘  │  │
│  │                                               │  │
│  │  ┌─────────────────────────────────────────┐  │  │
│  │  │         ViewModels (@Observable)         │  │  │
│  │  │  ScannerVM │ ResultsVM │ SettingsVM     │  │  │
│  │  └─────────────────────────────────────────┘  │  │
│  └──────────────────┬────────────────────────────┘  │
│                     │ Swift ↔ Rust FFI (C ABI)      │
│  ┌──────────────────▼────────────────────────────┐  │
│  │              Rust Core Engine                  │  │
│  │                                               │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────────┐  │  │
│  │  │ Scanner  │ │  Hasher  │ │   Storage    │  │  │
│  │  │ walkdir  │ │  blake3  │ │  rusqlite    │  │  │
│  │  │          │ │  rayon   │ │              │  │  │
│  │  └──────────┘ └──────────┘ └──────────────┘  │  │
│  │                                               │  │
│  │  ┌──────────────────────────────────────────┐ │  │
│  │  │           FFI Bridge (C ABI)             │ │  │
│  │  │  dedupo_scan_start() / _progress() /     │ │  │
│  │  │  _results() / _cancel() / _free()        │ │  │
│  │  └──────────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────┘  │
│                                                     │
│  ┌───────────────────────────────────────────────┐  │
│  │              SQLite Database                   │  │
│  │  file_index │ scan_history │ duplicate_groups  │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

---

## 3. 项目目录结构

```
DeDupo/
├── DeDupo.xcodeproj/              # Xcode 项目配置
├── DeDupo/                        # Swift 应用层
│   ├── App/
│   │   ├── DeDupoApp.swift        # 应用入口 @main
│   │   └── AppState.swift         # 全局应用状态
│   │
│   ├── Views/                     # SwiftUI 视图
│   │   ├── MainWindow.swift       # NavigationSplitView 主窗口
│   │   ├── Scanner/
│   │   │   ├── ScannerView.swift  # 扫描配置与启动
│   │   │   └── ScanProgressView.swift
│   │   ├── Results/
│   │   │   ├── ResultsView.swift  # 重复文件列表
│   │   │   ├── DuplicateGroupRow.swift
│   │   │   └── FileDetailView.swift
│   │   └── Settings/
│   │       └── SettingsView.swift
│   │
│   ├── ViewModels/                # @Observable ViewModels
│   │   ├── ScannerViewModel.swift
│   │   └── ResultsViewModel.swift
│   │
│   ├── Bridge/                    # Rust FFI 桥接层
│   │   ├── RustBridge.swift       # Swift 侧 FFI 封装
│   │   └── dedupo_ffi.h          # C 头文件 (Rust 生成)
│   │
│   ├── Models/                    # Swift 数据模型
│   │   ├── ScanTarget.swift       # 扫描目标 (路径、类型)
│   │   ├── DuplicateGroup.swift   # 重复文件组
│   │   └── FileEntry.swift        # 文件条目
│   │
│   ├── Services/                  # 业务服务
│   │   ├── VolumeMonitor.swift    # 监控挂载/卸载磁盘
│   │   └── TrashService.swift     # 移至废纸篓逻辑
│   │
│   ├── Resources/
│   │   └── Assets.xcassets
│   │
│   └── Info.plist
│
├── dedupo-core/                   # Rust 核心引擎
│   ├── Cargo.toml
│   ├── src/
│   │   ├── lib.rs                 # 库入口
│   │   ├── ffi.rs                 # C ABI 导出函数
│   │   ├── scanner/
│   │   │   ├── mod.rs
│   │   │   ├── walker.rs          # 文件遍历 (walkdir)
│   │   │   └── filter.rs          # 文件过滤规则
│   │   ├── hasher/
│   │   │   ├── mod.rs
│   │   │   ├── pipeline.rs        # 分层哈希管道
│   │   │   └── blake3.rs          # BLAKE3 哈希封装
│   │   ├── dedup/
│   │   │   ├── mod.rs
│   │   │   └── grouper.rs         # 重复文件分组逻辑
│   │   ├── storage/
│   │   │   ├── mod.rs
│   │   │   ├── database.rs        # SQLite 操作
│   │   │   └── schema.sql         # 建表语句
│   │   └── types.rs               # 共享类型定义
│   │
│   ├── build.rs                   # 生成 C 头文件 (cbindgen)
│   └── cbindgen.toml              # cbindgen 配置
│
├── scripts/
│   ├── build-rust.sh              # Xcode Build Phase 调用
│   └── package-dmg.sh             # DMG 打包脚本
│
├── docs/
│   └── architecture.md            # 本文档
│
└── README.md
```

---

## 4. 核心模块设计

### 4.1 分层哈希去重管道 (Rust 侧)

性能关键设计——绝大多数文件在前两层即被排除：

```
输入: 目标目录下所有文件
         │
         ▼
┌─────────────────────────┐
│ Layer 0: 文件大小分组     │  ← 零 I/O，仅读取元数据
│ 大小唯一 → 排除           │  ～排除 60-70% 文件
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│ Layer 1: 头部快速哈希     │  ← 读取前 4KB
│ BLAKE3(head_4KB)        │  ～再排除 20-25%
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│ Layer 2: 尾部快速哈希     │  ← 读取尾部 4KB
│ BLAKE3(tail_4KB)        │  ～再排除 3-5%
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│ Layer 3: 全文件哈希       │  ← 仅剩 ~5% 文件需要全量读取
│ BLAKE3(full_file)       │  ← rayon 并行处理
│ 哈希相同 → 确认重复       │
└────────────┬────────────┘
             ▼
输出: DuplicateGroup[]
```

### 4.2 FFI 桥接设计

**Rust → C ABI 导出 (ffi.rs)**

```rust
// ===== 生命周期管理 =====

/// 创建扫描引擎实例
#[no_mangle]
pub extern "C" fn dedupo_engine_create(db_path: *const c_char) -> *mut Engine;

/// 释放引擎实例
#[no_mangle]
pub extern "C" fn dedupo_engine_free(engine: *mut Engine);


// ===== 扫描控制 =====

/// 添加扫描目标路径
#[no_mangle]
pub extern "C" fn dedupo_add_scan_path(
    engine: *mut Engine,
    path: *const c_char,
) -> i32;

/// 启动异步扫描 (非阻塞)
/// callback: 进度回调, 参数 (scanned_count, total_estimated, phase)
#[no_mangle]
pub extern "C" fn dedupo_scan_start(
    engine: *mut Engine,
    progress_cb: extern "C" fn(u64, u64, i32, *mut c_void),
    context: *mut c_void,
) -> i32;

/// 取消正在进行的扫描
#[no_mangle]
pub extern "C" fn dedupo_scan_cancel(engine: *mut Engine);


// ===== 结果获取 =====

/// 获取重复文件组数量
#[no_mangle]
pub extern "C" fn dedupo_get_group_count(engine: *mut Engine) -> u64;

/// 获取指定组的详情 (返回 JSON 字符串)
#[no_mangle]
pub extern "C" fn dedupo_get_group(
    engine: *mut Engine,
    index: u64,
) -> *mut c_char;

/// 释放 Rust 分配的字符串
#[no_mangle]
pub extern "C" fn dedupo_free_string(s: *mut c_char);


// ===== 文件操作 =====

/// 删除指定文件 (移至废纸篓)
#[no_mangle]
pub extern "C" fn dedupo_trash_file(path: *const c_char) -> i32;
```

**Swift 侧封装 (RustBridge.swift)**

```swift
final class RustEngine: @unchecked Sendable {
    private let engine: OpaquePointer

    init(dbPath: String) {
        engine = dbPath.withCString { dedupo_engine_create($0) }
    }

    deinit {
        dedupo_engine_free(engine)
    }

    func addScanPath(_ path: String) {
        path.withCString { dedupo_add_scan_path(engine, $0) }
    }

    func startScan(onProgress: @escaping (UInt64, UInt64, ScanPhase) -> Void) {
        // 通过 callback + context 桥接到 Swift 闭包
    }

    func getGroups() -> [DuplicateGroup] {
        // 获取 JSON → 解码为 Swift 模型
    }
}
```

### 4.3 数据库 Schema (SQLite)

```sql
-- 文件指纹索引 (支持增量扫描, MVP 后期加入)
CREATE TABLE file_index (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    path          TEXT NOT NULL UNIQUE,
    size          INTEGER NOT NULL,
    modified_at   INTEGER NOT NULL,  -- Unix timestamp
    head_hash     TEXT,              -- BLAKE3(前4KB)
    tail_hash     TEXT,              -- BLAKE3(尾4KB)
    full_hash     TEXT,              -- BLAKE3(全文件)
    last_scanned  INTEGER NOT NULL,  -- 上次扫描时间
    volume_id     TEXT               -- 磁盘/卷标识
);

CREATE INDEX idx_file_size ON file_index(size);
CREATE INDEX idx_file_full_hash ON file_index(full_hash);

-- 扫描历史
CREATE TABLE scan_history (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    started_at    INTEGER NOT NULL,
    finished_at   INTEGER,
    scan_paths    TEXT NOT NULL,     -- JSON array
    total_files   INTEGER,
    total_size    INTEGER,           -- bytes
    duplicates    INTEGER,
    saved_space   INTEGER            -- bytes
);

-- 重复文件组 (扫描结果)
CREATE TABLE duplicate_groups (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    scan_id       INTEGER NOT NULL REFERENCES scan_history(id),
    group_hash    TEXT NOT NULL,     -- 共同的 full_hash
    file_count    INTEGER NOT NULL,
    file_size     INTEGER NOT NULL,  -- 单个文件大小
    wasted_space  INTEGER NOT NULL   -- (file_count - 1) * file_size
);

-- 组内文件
CREATE TABLE duplicate_files (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    group_id      INTEGER NOT NULL REFERENCES duplicate_groups(id),
    file_path     TEXT NOT NULL,
    is_kept       BOOLEAN DEFAULT 1, -- 用户选择保留
    volume_name   TEXT               -- 所在卷名称
);
```

### 4.4 SwiftUI 视图层设计

**主窗口布局：NavigationSplitView**

```
┌──────────────────────────────────────────────────────┐
│  DeDupo                                    ─ □ ✕    │
├──────────┬───────────────────────────────────────────┤
│          │                                           │
│ Sidebar  │            Detail Area                    │
│          │                                           │
│ 📂 扫描   │  ┌─ ScannerView ──────────────────────┐  │
│ 📊 结果   │  │                                     │  │
│ ⚙️ 设置   │  │  拖放文件夹或点击选择扫描目标          │  │
│          │  │                                     │  │
│          │  │  ┌──────────────────────────────┐   │  │
│ ─────── │  │  │  /Users/kory/Documents   ✕  │   │  │
│          │  │  │  /Volumes/NAS/Photos     ✕  │   │  │
│ 磁盘列表  │  │  └──────────────────────────────┘   │  │
│          │  │                                     │  │
│ 💻 Macintosh│  │  [▶ 开始扫描]                       │  │
│ 📁 NAS    │  │                                     │  │
│ 💾 移动硬盘│  └─────────────────────────────────────┘  │
│          │                                           │
└──────────┴───────────────────────────────────────────┘
```

**结果视图布局**

```
┌──────────┬───────────────────────────────────────────┐
│          │  扫描完成: 找到 128 组重复文件               │
│ Sidebar  │  可节省空间: 4.2 GB                        │
│          │                                           │
│          │  排序: 文件大小 ▼  │ 筛选: 全部类型 ▼       │
│          │                                           │
│          │  ┌─ Group 1 ──── 512 MB ─────────────┐   │
│          │  │ ☑ /Users/docs/video.mp4     512MB  │   │
│          │  │ ☐ /Volumes/NAS/video.mp4    512MB  │   │
│          │  │ ☐ /Volumes/Backup/video.mp4 512MB  │   │
│          │  └────────────────────────────────────┘   │
│          │                                           │
│          │  ┌─ Group 2 ──── 128 MB ─────────────┐   │
│          │  │ ☑ /Users/Photos/IMG001.jpg   64MB  │   │
│          │  │ ☐ /Volumes/NAS/IMG001.jpg    64MB  │   │
│          │  └────────────────────────────────────┘   │
│          │                                           │
│          │            [🗑 删除选中的重复文件]            │
└──────────┴───────────────────────────────────────────┘
```

---

## 5. Rust Crate 依赖

```toml
[package]
name = "dedupo-core"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["staticlib"]     # 编译为 .a 静态库

[dependencies]
walkdir = "2"                  # 递归文件遍历
blake3 = "1"                   # 高性能哈希
rayon = "1.10"                 # 数据并行
rusqlite = { version = "0.32", features = ["bundled"] }  # SQLite
serde = { version = "1", features = ["derive"] }
serde_json = "1"               # FFI 数据交换格式
log = "0.4"
thiserror = "2"                # 错误处理

[build-dependencies]
cbindgen = "0.27"              # 自动生成 C 头文件
```

---

## 6. 构建流程

### Xcode Build Phase 集成

在 Xcode 项目中添加 **Run Script Build Phase**（置于 Compile Sources 之前）：

```bash
#!/bin/bash
# scripts/build-rust.sh

set -e

RUST_DIR="${SRCROOT}/dedupo-core"
cd "$RUST_DIR"

# 根据 Xcode 构建架构选择 Rust target
if [ "$PLATFORM_NAME" = "macosx" ]; then
    if [ "$ARCHS" = "arm64" ]; then
        RUST_TARGET="aarch64-apple-darwin"
    else
        RUST_TARGET="x86_64-apple-darwin"
    fi
fi

# 构建模式
if [ "$CONFIGURATION" = "Release" ]; then
    cargo build --release --target "$RUST_TARGET"
    LIB_PATH="target/$RUST_TARGET/release"
else
    cargo build --target "$RUST_TARGET"
    LIB_PATH="target/$RUST_TARGET/debug"
fi

# 拷贝静态库到 Xcode 可访问路径
cp "$LIB_PATH/libdedupo_core.a" "${BUILT_PRODUCTS_DIR}/"

# 生成 C 头文件
cbindgen --config cbindgen.toml --crate dedupo-core \
    --output "${SRCROOT}/DeDupo/Bridge/dedupo_ffi.h"
```

### Universal Binary (可选)

```bash
# 同时编译 arm64 + x86_64, 合并为 Universal Binary
cargo build --release --target aarch64-apple-darwin
cargo build --release --target x86_64-apple-darwin

lipo -create \
    target/aarch64-apple-darwin/release/libdedupo_core.a \
    target/x86_64-apple-darwin/release/libdedupo_core.a \
    -output libdedupo_core_universal.a
```

---

## 7. MVP 功能范围

### MVP 包含

| 功能 | 说明 |
|------|------|
| 目录选择 | 拖放 + 文件选择器，支持多目录 |
| 本地磁盘扫描 | 递归遍历，尊重系统权限 |
| 挂载卷扫描 | 已挂载的 NAS / 移动硬盘 |
| 分层哈希去重 | 4 层过滤管道 |
| 扫描进度 | 实时显示阶段、文件数、预估时间 |
| 结果展示 | 按组显示重复文件，展示路径和大小 |
| 智能保留建议 | 默认勾选保留"最原始"的副本 |
| 移至废纸篓 | 安全删除，用户可恢复 |
| 磁盘监控 | 自动检测挂载/卸载的外部磁盘 |

### MVP 不包含 (后续迭代)

| 功能 | 优先级 |
|------|--------|
| 增量扫描 (跳过未修改文件) | P1 - 第二版 |
| 文件预览对比 (图片/文档) | P1 - 第二版 |
| Sparkle 自动更新 | P2 |
| 扫描规则自定义 (排除目录/类型) | P2 |
| Finder 右键菜单集成 | P3 |
| 相似文件检测 (非完全相同) | P3 |
| Windows 端 (Tauri + Rust Core) | P3 |

---

## 8. 开发里程碑

```
Phase 1: 基础框架搭建               (Week 1-2)
├── Xcode 项目 + Rust workspace 初始化
├── FFI 桥接 Hello World 打通
├── SwiftUI 主窗口骨架
└── SQLite 数据库初始化

Phase 2: 核心扫描引擎               (Week 3-4)
├── 文件遍历器 (walkdir + 过滤)
├── 分层哈希管道实现
├── rayon 并行哈希
└── 进度回调机制

Phase 3: 结果展示与操作              (Week 5-6)
├── 重复文件分组展示
├── 排序/筛选功能
├── 智能保留建议算法
└── 移至废纸篓功能

Phase 4: 打磨与分发                 (Week 7-8)
├── 外部磁盘检测与集成
├── UI 细节打磨 (动画/暗色模式)
├── 性能优化 (大规模文件测试)
└── DMG 打包 + 代码签名
```

---

## 9. 关键技术决策备忘

| 决策 | 选择 | 原因 |
|------|------|------|
| 哈希算法 | BLAKE3 | 比 SHA256 快 5-10x，比 xxHash 有更强碰撞抗性 |
| FFI 数据格式 | JSON over C strings | 复杂结构传递简单，性能损耗可接受 |
| 并发模型 | Rust: rayon / Swift: async/await | 各自生态最佳实践 |
| 数据库 | SQLite (rusqlite bundled) | 零部署，Rust 侧直接操作，无跨语言 DB 驱动问题 |
| 删除策略 | 移至废纸篓 | 安全可逆，用户心智负担低 |
| macOS 版本 | 15+ | 最新 SwiftUI API，减少兼容负担 |
| 分发 | DMG + 公证 | 无沙盒限制，文件系统完全访问 |
