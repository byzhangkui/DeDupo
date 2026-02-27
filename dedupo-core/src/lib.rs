//! DeDupo Core — High-performance file deduplication engine.
//!
//! This crate provides the core scanning, hashing, and deduplication logic
//! for the DeDupo application. It exposes a C ABI for integration with the
//! SwiftUI frontend via FFI.

pub mod dedup;
pub mod ffi;
pub mod hasher;
pub mod scanner;
pub mod storage;
pub mod types;

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};

use types::{DeDupoError, DuplicateGroup, Result, ScanConfig, ScanPhase, ScanProgress};

/// The main engine that coordinates scanning and deduplication.
pub struct Engine {
    config: ScanConfig,
    db: storage::Database,
    results: Mutex<Vec<DuplicateGroup>>,
    cancelled: Arc<AtomicBool>,
}

impl Engine {
    /// Create a new engine instance with the given database path.
    pub fn new(db_path: &str) -> Result<Self> {
        let db = storage::Database::open(db_path)?;
        db.initialize()?;

        Ok(Self {
            config: ScanConfig::default(),
            db,
            results: Mutex::new(Vec::new()),
            cancelled: Arc::new(AtomicBool::new(false)),
        })
    }

    /// Add a directory path to scan.
    pub fn add_scan_path(&mut self, path: &str) {
        self.config.paths.push(path.to_string());
    }

    /// Run the full deduplication pipeline.
    ///
    /// The `progress_cb` is called periodically with scan progress updates.
    pub fn scan<F>(&self, progress_cb: F) -> Result<()>
    where
        F: Fn(ScanProgress) + Send + Sync,
    {
        self.cancelled.store(false, Ordering::SeqCst);

        // Phase 0: Enumerate files
        progress_cb(ScanProgress {
            scanned_count: 0,
            total_estimated: 0,
            phase: ScanPhase::Enumerating,
        });

        let files = scanner::walk_directories(&self.config.paths, &self.cancelled)?;
        let total = files.len() as u64;

        if self.cancelled.load(Ordering::SeqCst) {
            return Err(DeDupoError::Cancelled);
        }

        // Phase 1: Group by size (Layer 0)
        progress_cb(ScanProgress {
            scanned_count: 0,
            total_estimated: total,
            phase: ScanPhase::SizeGrouping,
        });

        let size_groups = dedup::grouper::group_by_size(files);
        let candidates: Vec<_> = size_groups
            .into_iter()
            .filter(|(_, group)| group.len() > 1)
            .flat_map(|(_, group)| group)
            .collect();

        if self.cancelled.load(Ordering::SeqCst) {
            return Err(DeDupoError::Cancelled);
        }

        // Phase 2: Head hash (Layer 1)
        progress_cb(ScanProgress {
            scanned_count: 0,
            total_estimated: candidates.len() as u64,
            phase: ScanPhase::HeadHashing,
        });

        let head_hashed =
            hasher::pipeline::hash_heads(&candidates, self.config.head_hash_bytes, &self.cancelled)?;
        let head_groups = dedup::grouper::group_by_head_hash(head_hashed);
        let candidates: Vec<_> = head_groups
            .into_iter()
            .filter(|(_, group)| group.len() > 1)
            .flat_map(|(_, group)| group)
            .collect();

        if self.cancelled.load(Ordering::SeqCst) {
            return Err(DeDupoError::Cancelled);
        }

        // Phase 3: Tail hash (Layer 2)
        progress_cb(ScanProgress {
            scanned_count: 0,
            total_estimated: candidates.len() as u64,
            phase: ScanPhase::TailHashing,
        });

        let tail_hashed =
            hasher::pipeline::hash_tails(&candidates, self.config.tail_hash_bytes, &self.cancelled)?;
        let tail_groups = dedup::grouper::group_by_tail_hash(tail_hashed);
        let candidates: Vec<_> = tail_groups
            .into_iter()
            .filter(|(_, group)| group.len() > 1)
            .flat_map(|(_, group)| group)
            .collect();

        if self.cancelled.load(Ordering::SeqCst) {
            return Err(DeDupoError::Cancelled);
        }

        // Phase 4: Full file hash (Layer 3)
        progress_cb(ScanProgress {
            scanned_count: 0,
            total_estimated: candidates.len() as u64,
            phase: ScanPhase::FullHashing,
        });

        let full_hashed = hasher::pipeline::hash_full(&candidates, &self.cancelled)?;
        let duplicate_groups = dedup::grouper::build_duplicate_groups(full_hashed);

        // Store results
        {
            let mut results = self.results.lock().unwrap();
            *results = duplicate_groups;
        }

        progress_cb(ScanProgress {
            scanned_count: total,
            total_estimated: total,
            phase: ScanPhase::Complete,
        });

        Ok(())
    }

    /// Cancel an ongoing scan.
    pub fn cancel(&self) {
        self.cancelled.store(true, Ordering::SeqCst);
    }

    /// Get the number of duplicate groups found.
    pub fn group_count(&self) -> u64 {
        self.results.lock().unwrap().len() as u64
    }

    /// Get a specific duplicate group by index (as JSON).
    pub fn get_group_json(&self, index: u64) -> Option<String> {
        let results = self.results.lock().unwrap();
        results
            .get(index as usize)
            .and_then(|g| serde_json::to_string(g).ok())
    }

    /// Get a reference to the database.
    pub fn database(&self) -> &storage::Database {
        &self.db
    }
}
