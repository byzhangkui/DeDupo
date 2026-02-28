# DeDupo 开发进度

> 最后更新：2026-02-28

---

## 当前阶段：Phase 1 — 基础框架搭建

### 已完成

#### 1. 项目脚手架搭建 (Commit: `8a82782`)

**Swift 应用层：**
- `DeDupoApp.swift` — 应用入口 @main
- `AppState.swift` — 全局应用状态管理
- `MainWindow.swift` — NavigationSplitView 主窗口骨架
- `ScannerView.swift` / `ScanProgressView.swift` — 扫描配置与进度视图
- `ResultsView.swift` / `DuplicateGroupRow.swift` / `FileDetailView.swift` — 结果展示视图
- `SettingsView.swift` — 设置视图
- `ScannerViewModel.swift` / `ResultsViewModel.swift` — ViewModel 层
- `RustBridge.swift` — Swift 侧 FFI 桥接封装
- `VolumeMonitor.swift` — 外部磁盘挂载/卸载监控
- `TrashService.swift` — 移至废纸篓服务

**Rust 核心引擎 (`dedupo-core`)：**
- `scanner/walker.rs` — 文件遍历器（walkdir）
- `scanner/filter.rs` — 文件过滤器
- `hasher/blake3_hash.rs` — BLAKE3 哈希计算
- `hasher/pipeline.rs` — 分层哈希管道
- `dedup/grouper.rs` — 重复文件分组
- `storage/database.rs` + `schema.sql` — SQLite 数据库
- `ffi.rs` — C ABI FFI 导出函数
- `types.rs` — 共享数据类型

**模型定义：**
- `DuplicateGroup.swift` / `FileEntry.swift` / `ScanTarget.swift`

#### 2. 架构设计文档 (Commit: `623c4ad`)

- `docs/architecture.md` — 完整的中文架构设计文档，包含系统架构图、目录结构、分层哈希管道、FFI 桥接设计、数据库 Schema、UI 布局、MVP 范围、开发里程碑等

#### 3. 构建系统 (Commit: `0626103`)

- `project.yml` — XcodeGen 配置，自动生成 `.xcodeproj`
- `docs/build-guide.md` — 新手构建指南（工具安装、编译、运行、打包、FAQ）
- `scripts/build-rust.sh` — Rust 编译脚本
- `scripts/package-dmg.sh` — DMG 打包脚本

#### 4. 构建问题修复 (Commit: `b376ede`)

- 为 Xcode Build Phase 脚本添加 `$HOME/.cargo/bin` PATH
- `VolumeMonitor.swift` 补充 `import AppKit`
- `ScannerViewModel` 添加 `@MainActor` 修复 Swift 6 并发安全
- `dedupo_ffi.h` 由 cbindgen 重新生成
- 添加 `Cargo.lock` 确保可重复构建

---

### 进行中

_（暂无，等待启动 Phase 2）_

---

## 后续计划

### Phase 2: 核心扫描引擎（下一步重点）

| 任务 | 说明 | 状态 |
|------|------|------|
| 文件遍历器完善 | walkdir 递归遍历 + 符号链接处理 + 权限跳过 | 待开始 |
| 分层哈希管道实现 | 文件大小 → Head Hash (4KB) → Tail Hash → Full Hash 四层过滤 | 待开始 |
| rayon 并行哈希 | 多线程并行计算文件哈希 | 待开始 |
| 进度回调机制 | FFI 回调 Swift 侧，实时更新扫描进度 | 待开始 |
| FFI 桥接联调 | Swift ↔ Rust 端到端打通，真实扫描流程跑通 | 待开始 |

### Phase 3: 结果展示与操作

| 任务 | 说明 |
|------|------|
| 重复文件分组展示 | 按组显示，展示路径、大小、修改时间 |
| 排序/筛选功能 | 按大小、文件数、类型排序和筛选 |
| 智能保留建议算法 | 默认勾选"最原始"的副本（最早创建时间） |
| 移至废纸篓功能 | 安全删除，用户可通过废纸篓恢复 |

### Phase 4: 打磨与分发

| 任务 | 说明 |
|------|------|
| 外部磁盘检测集成 | 自动检测挂载/卸载的 NAS、移动硬盘 |
| UI 细节打磨 | 动画、暗色模式适配 |
| 性能优化 | 大规模文件（10万+）压力测试 |
| DMG 打包 + 代码签名 | 公证、分发准备 |

---

## 项目结构概览

```
DeDupo/
├── DeDupo/                    # Swift 应用层
│   ├── App/                   # 应用入口、全局状态
│   ├── Bridge/                # FFI 桥接（RustBridge.swift + dedupo_ffi.h）
│   ├── Models/                # 数据模型
│   ├── Services/              # 系统服务（废纸篓、磁盘监控）
│   ├── ViewModels/            # MVVM ViewModel
│   └── Views/                 # SwiftUI 视图
├── dedupo-core/               # Rust 核心引擎
│   └── src/
│       ├── scanner/           # 文件遍历与过滤
│       ├── hasher/            # BLAKE3 哈希与管道
│       ├── dedup/             # 重复文件分组
│       ├── storage/           # SQLite 存储
│       ├── ffi.rs             # C ABI 导出
│       └── types.rs           # 共享类型
├── docs/                      # 文档
│   ├── architecture.md        # 架构设计
│   └── build-guide.md         # 构建指南
├── scripts/                   # 构建/打包脚本
├── project.yml                # XcodeGen 配置
└── PROGRESS.md                # 本文件
```
