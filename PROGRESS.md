# DeDupo — 开发进度

## 当前状态：Phase 1 基本完成，可编译运行

项目已完成基础框架搭建，Rust 核心引擎 + SwiftUI 前端 + FFI 桥接层已全部就绪，`⌘+R` 可成功编译运行。

---

## 已实现内容

### Rust 核心引擎 (dedupo-core)

| 模块 | 文件 | 状态 | 说明 |
|------|------|------|------|
| Engine 主协调器 | `lib.rs` | ✅ 完成 | `Engine` 结构体，完整的 4 层扫描管道调度，取消机制，结果存取 |
| 类型定义 | `types.rs` | ✅ 完成 | `FileEntry`, `DuplicateGroup`, `DuplicateFile`, `ScanPhase`, `ScanProgress`, `ScanConfig`, `DeDupoError` |
| FFI 导出 | `ffi.rs` | ✅ 完成 | 完整的 C ABI：`create/free/add_path/scan_start/cancel/get_count/get_group/free_string/trash_file`，含 `SendPtr` 跨线程安全包装 |
| 文件遍历 | `scanner/walker.rs` | ✅ 完成 | 基于 walkdir 递归遍历，跳过符号链接、目录、空文件，收集元数据 |
| 文件过滤 | `scanner/filter.rs` | ✅ 完成 | 跳过 `.Trash`, `.Spotlight-V100`, `.git`, `node_modules` 等系统/缓存目录 |
| 多目录遍历 | `scanner/mod.rs` | ✅ 完成 | `walk_directories()` 支持多个扫描路径，逐个遍历 |
| BLAKE3 哈希 | `hasher/blake3_hash.rs` | ✅ 完成 | `hash_head` (前 N 字节)、`hash_tail` (尾 N 字节)、`hash_full` (流式全文件哈希，64KB 缓冲)，含单元测试 |
| 分层哈希管道 | `hasher/pipeline.rs` | ✅ 完成 | `hash_heads/hash_tails/hash_full` 三个阶段，均使用 rayon 并行处理，支持取消 |
| 分组器 | `dedup/grouper.rs` | ✅ 完成 | 4 层过滤：`group_by_size` → `group_by_head_hash` → `group_by_tail_hash` → `build_duplicate_groups`，智能保留最旧文件，按浪费空间排序，含单元测试 |
| SQLite 数据库 | `storage/database.rs` | ✅ 完成 | WAL 模式，`initialize/start_scan/finish_scan/save_duplicate_groups/upsert_file_index` |
| 数据库 Schema | `storage/schema.sql` | ✅ 完成 | `file_index` + `scan_history` + `duplicate_groups` + `duplicate_files` 四张表，含索引 |
| C 头文件生成 | `build.rs` + `cbindgen.toml` | ✅ 完成 | cbindgen 自动生成 `dedupo_ffi.h` |

### SwiftUI 前端 (DeDupo)

| 模块 | 文件 | 状态 | 说明 |
|------|------|------|------|
| App 入口 | `DeDupoApp.swift` | ✅ 完成 | `@main`，`WindowGroup` + `Settings` Scene，默认 900x600 |
| 全局状态 | `AppState.swift` | ✅ 完成 | `RustEngine` 初始化（数据库在 `~/Library/Application Support/DeDupo/`），侧边栏导航 |
| FFI 桥接 | `RustBridge.swift` | ✅ 完成 | `RustEngine` 类完整封装所有 FFI 调用，`ProgressCallbackBox` + trampoline 回调桥接 |
| 主窗口 | `MainWindow.swift` | ✅ 完成 | `NavigationSplitView`，侧边栏含导航项 + 磁盘列表，Detail 区域按选中项切换 |
| 扫描配置 | `ScannerView.swift` | ✅ 完成 | 拖放区域 + `NSOpenPanel` 文件夹选择器 + 目标列表 + 开始按钮 + 错误提示 |
| 扫描进度 | `ScanProgressView.swift` | ✅ 完成 | 线性进度条 + 阶段描述 + 文件计数 + 取消按钮 |
| 扫描 ViewModel | `ScannerViewModel.swift` | ✅ 完成 | `@MainActor`，管理扫描目标、进度状态、后台执行扫描任务 |
| 结果列表 | `ResultsView.swift` | ✅ 完成 | 空状态 + 汇总栏 + 排序控件 + 分组列表 + "Delete Selected" 功能 (Commit: `97f70ab`) |
| 分组行 | `DuplicateGroupRow.swift` | ✅ 完成 | `DisclosureGroup` 展开/折叠，文件勾选/取消保留，路径显示，卷名标签 |
| 文件详情 | `FileDetailView.swift` | ✅ 完成 | 路径、大小、卷、状态显示 + 在 Finder 中显示 + Quick Look |
| 结果 ViewModel | `ResultsViewModel.swift` | ✅ 完成 | 排序（大小/浪费空间/文件数）+ 保留切换 + 待删除统计 + 可恢复空间计算 |
| 数据模型 | `DuplicateGroup.swift`, `DuplicateFile.swift`, `FileEntry.swift`, `ScanTarget.swift` | ✅ 完成 | Codable，snake_case JSON 映射，计算属性 |
| 磁盘监控 | `VolumeMonitor.swift` | ✅ 完成 | 监听挂载/卸载通知，返回 `VolumeInfo` 列表，区分内部/外部磁盘 |
| 移至废纸篓 | `TrashService.swift` | ✅ 完成 | `FileManager.trashItem` 单文件/批量删除 |
| 设置页面 | `SettingsView.swift` | ✅ 完成 | 跳过隐藏文件、跳过系统目录、最小文件大小设置 + 版本信息 |
| 删除确认对话框 | `ResultsView.swift` | ✅ 完成 | 删除前弹出确认 Alert，防止误操作 (Commit: `e90dcaa`) |
| 扫描自动跳转 | `MainWindow.swift` | ✅ 完成 | 扫描完成后 `selectedNavigation` 自动切换到 `.results` (Commit: `72941f6`) |

### 构建系统

| 项目 | 状态 | 说明 |
|------|------|------|
| XcodeGen 配置 | ✅ 完成 | `project.yml` 含 Rust 库搜索路径、链接配置、Pre-build Script |
| Rust 构建脚本 | ✅ 完成 | `scripts/build-rust.sh`，自动检测架构，含 PATH 修复 |
| DMG 打包脚本 | ✅ 完成 | `scripts/package-dmg.sh`，支持 `create-dmg` 和 `hdiutil` 回退 |
| 编译通过 | ✅ 完成 | `xcodebuild` Debug 配置编译成功 |

### 文档

| 文档 | 状态 |
|------|------|
| `docs/architecture.md` | ✅ 完成 — 完整中文架构设计文档 |
| `docs/build-guide.md` | ✅ 完成 — 开发环境搭建指南 |
| `README.md` | ✅ 完成 — 项目简介与快速开始 |
| `PROGRESS.md` | ✅ 同步 — 开发进度实时同步 |

---

## 尚未实现 / 需要完善

### 功能集成（将已实现的模块串联起来）

| 项目 | 优先级 | 说明 |
|------|--------|------|
| VolumeMonitor 接入 AppState | P0 | `AppState.init` 中需启动 `VolumeMonitor`，将卷信息同步到 `mountedVolumes` |
| 扫描结果持久化 | P0 | `Engine.scan()` 完成后需调用 `db.start_scan/save_duplicate_groups/finish_scan` 写入数据库 |
| Settings 实际生效 | P1 | `SettingsView` 中的设置（跳过隐藏文件、最小文件大小）未传递给 Rust 引擎 |

### 架构文档中规划但未实现的 MVP 功能

| 功能 | 优先级 | 说明 |
|------|--------|------|
| 扫描进度精确化 | P1 | 当前各阶段 `scanned_count` 均为 0 或粗略值，需在 rayon 并行中加入实时计数 |
| 错误提示完善 | P2 | 权限不足、路径不存在等错误需友好展示给用户 |
| 暗色模式适配 | P2 | 当前使用系统默认，可能需要检查自定义颜色 |
| 代码签名 + 公证 | P2 | 分发前需配置签名和 Apple 公证 |

### Post-MVP（架构文档 §7 规划）

| 功能 | 优先级 |
|------|--------|
| 增量扫描（跳过未修改文件） | P1 |
| 文件预览对比（图片/文档） | P1 |
| Sparkle 自动更新 | P2 |
| 扫描规则自定义（排除目录/类型） | P2 |
| Finder 右键菜单集成 | P3 |
| 相似文件检测（非完全相同） | P3 |
| Windows 端 (Tauri + Rust Core) | P3 |

---

## 开发里程碑对照

```
Phase 1: 基础框架搭建 ✅ 已完成
├── ✅ Xcode 项目 + Rust workspace 初始化
├── ✅ FFI 桥接打通（完整的 create/scan/results/cancel 链路）
├── ✅ SwiftUI 主窗口骨架（NavigationSplitView + 三页面）
└── ✅ SQLite 数据库初始化（schema + CRUD 方法）

Phase 2: 核心扫描引擎 ✅ 已完成
├── ✅ 文件遍历器 (walkdir + 过滤)
├── ✅ 分层哈希管道实现（4 层完整）
├── ✅ rayon 并行哈希
└── ✅ 进度回调机制

Phase 3: 结果展示与操作 🔧 基本完成，待串联
├── ✅ 重复文件分组展示（UI 已实现）
├── ✅ 排序/筛选功能（ViewModel 已实现）
├── ✅ 智能保留建议算法（最旧文件保留）
├── 🔲 移至废纸篓功能（TrashService 已实现，未接入 UI）
└── 🔲 扫描结果持久化（Database 方法已实现，未调用）

Phase 4: 打磨与分发 🔲 未开始
├── 🔲 外部磁盘检测集成（VolumeMonitor 已实现，未接入 AppState）
├── 🔲 UI 细节打磨（动画/暗色模式）
├── 🔲 性能优化（大规模文件测试）
└── 🔲 DMG 打包 + 代码签名
```

---

*最后更新：2026-03-02*
