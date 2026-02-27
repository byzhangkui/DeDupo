-- DeDupo Database Schema

-- File fingerprint index (supports incremental scanning)
CREATE TABLE IF NOT EXISTS file_index (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    path          TEXT NOT NULL UNIQUE,
    size          INTEGER NOT NULL,
    modified_at   INTEGER NOT NULL,  -- Unix timestamp
    head_hash     TEXT,              -- BLAKE3(first 4KB)
    tail_hash     TEXT,              -- BLAKE3(last 4KB)
    full_hash     TEXT,              -- BLAKE3(full file)
    last_scanned  INTEGER NOT NULL,  -- Last scan timestamp
    volume_id     TEXT               -- Disk/volume identifier
);

CREATE INDEX IF NOT EXISTS idx_file_size ON file_index(size);
CREATE INDEX IF NOT EXISTS idx_file_full_hash ON file_index(full_hash);

-- Scan history
CREATE TABLE IF NOT EXISTS scan_history (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    started_at    INTEGER NOT NULL,
    finished_at   INTEGER,
    scan_paths    TEXT NOT NULL,     -- JSON array
    total_files   INTEGER,
    total_size    INTEGER,           -- bytes
    duplicates    INTEGER,
    saved_space   INTEGER            -- bytes
);

-- Duplicate file groups (scan results)
CREATE TABLE IF NOT EXISTS duplicate_groups (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    scan_id       INTEGER NOT NULL REFERENCES scan_history(id),
    group_hash    TEXT NOT NULL,     -- Shared full_hash
    file_count    INTEGER NOT NULL,
    file_size     INTEGER NOT NULL,  -- Single file size
    wasted_space  INTEGER NOT NULL   -- (file_count - 1) * file_size
);

-- Files within a duplicate group
CREATE TABLE IF NOT EXISTS duplicate_files (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    group_id      INTEGER NOT NULL REFERENCES duplicate_groups(id),
    file_path     TEXT NOT NULL,
    is_kept       BOOLEAN DEFAULT 1, -- User chose to keep
    volume_name   TEXT               -- Volume name
);
