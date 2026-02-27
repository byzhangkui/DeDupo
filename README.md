# DeDupo

A macOS native file deduplication tool built with **SwiftUI** and a **Rust** core engine.

## Features

- **Fast 4-layer deduplication pipeline** — eliminates ~95% of files before full hashing
- **BLAKE3 hashing** — 5-10x faster than SHA256
- **Parallel processing** — rayon-powered multi-threaded file hashing
- **External volume support** — scan NAS, external drives, and mounted volumes
- **Smart retain suggestions** — automatically suggests keeping the oldest copy
- **Safe deletion** — moves files to Trash (recoverable)
- **SQLite persistence** — scan history and file index for future incremental scanning

## Architecture

```
SwiftUI Views → ViewModels (@Observable) → Rust FFI (C ABI) → Core Engine
```

- **Swift layer**: UI, navigation, file selection, trash integration
- **Rust layer**: File walking, BLAKE3 hashing, SQLite storage, dedup logic
- **Bridge**: C ABI with JSON data exchange via cbindgen-generated headers

See [docs/architecture.md](docs/architecture.md) for detailed design.

## Project Structure

```
DeDupo/
├── DeDupo/                  # Swift application layer
│   ├── App/                 # @main entry, AppState
│   ├── Views/               # SwiftUI views (Scanner, Results, Settings)
│   ├── ViewModels/          # @Observable view models
│   ├── Bridge/              # Rust FFI bridge (RustBridge.swift, dedupo_ffi.h)
│   ├── Models/              # Swift data models
│   └── Services/            # VolumeMonitor, TrashService
├── dedupo-core/             # Rust core engine
│   ├── src/
│   │   ├── scanner/         # File traversal (walkdir)
│   │   ├── hasher/          # BLAKE3 hashing pipeline
│   │   ├── dedup/           # Duplicate grouping logic
│   │   ├── storage/         # SQLite database
│   │   ├── ffi.rs           # C ABI exports
│   │   └── types.rs         # Shared type definitions
│   ├── Cargo.toml
│   └── cbindgen.toml
├── scripts/
│   ├── build-rust.sh        # Xcode Build Phase script
│   └── package-dmg.sh       # DMG packaging script
└── docs/
    └── architecture.md
```

## Prerequisites

- macOS 15 (Sequoia) or later
- Xcode 16+
- Rust toolchain (`rustup`)
- `cbindgen` (`cargo install cbindgen`)

## Building

### Rust Core

```bash
cd dedupo-core
cargo build
```

### Full App (via Xcode)

1. Open `DeDupo.xcodeproj` in Xcode
2. The Rust library is built automatically via the Build Phase script
3. Build and run (Cmd+R)

### DMG Package

```bash
./scripts/package-dmg.sh build/Release/DeDupo.app
```

## Requirements

- macOS 15+
- Full Disk Access permission (for scanning all directories)

## License

All rights reserved.
