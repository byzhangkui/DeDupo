# DeDupo — Architecture Design

## 1. Project Overview

| Item | Description |
|------|-------------|
| **Name** | DeDupo |
| **Purpose** | macOS native file deduplication tool |
| **Architecture** | SwiftUI (UI) + Rust Core (engine) |
| **Minimum OS** | macOS 15 (Sequoia) |
| **Distribution** | DMG direct distribution + Sparkle auto-update |
| **Target** | Mac first; Rust Core reusable for future Windows port |

## 2. System Architecture

```
┌─────────────────────────────────────────────────────┐
│                    DeDupo.app                        │
│                                                     │
│  ┌───────────────────────────────────────────────┐  │
│  │              SwiftUI Layer                     │  │
│  │  Views → ViewModels (@Observable)              │  │
│  └──────────────────┬────────────────────────────┘  │
│                     │ Swift ↔ Rust FFI (C ABI)      │
│  ┌──────────────────▼────────────────────────────┐  │
│  │              Rust Core Engine                  │  │
│  │  Scanner (walkdir) │ Hasher (blake3/rayon)     │  │
│  │  Storage (rusqlite) │ FFI Bridge (C ABI)       │  │
│  └───────────────────────────────────────────────┘  │
│                                                     │
│  ┌───────────────────────────────────────────────┐  │
│  │  SQLite: file_index │ scan_history │ groups    │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

## 3. Layered Hash Deduplication Pipeline

Performance-critical design — most files are eliminated in the first two layers:

1. **Layer 0: File Size Grouping** — Zero I/O, metadata only (~60-70% eliminated)
2. **Layer 1: Head Hash** — BLAKE3 of first 4KB (~20-25% more eliminated)
3. **Layer 2: Tail Hash** — BLAKE3 of last 4KB (~3-5% more eliminated)
4. **Layer 3: Full File Hash** — BLAKE3 of entire file, rayon-parallel (~5% remaining)

## 4. Key Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Hash algorithm | BLAKE3 | 5-10x faster than SHA256, stronger collision resistance than xxHash |
| FFI data format | JSON over C strings | Simple complex structure passing, acceptable performance cost |
| Concurrency | Rust: rayon / Swift: async/await | Best practices for each ecosystem |
| Database | SQLite (rusqlite bundled) | Zero deployment, Rust-side direct operation |
| Delete strategy | Move to Trash | Safe, reversible, low user cognitive burden |
| macOS version | 15+ | Latest SwiftUI APIs, reduced compatibility burden |
| Distribution | DMG + notarization | No sandbox restrictions, full filesystem access |
