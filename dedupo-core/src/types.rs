use serde::{Deserialize, Serialize};
use thiserror::Error;

/// Errors that can occur in the dedupo core engine.
#[derive(Error, Debug)]
pub enum DeDupoError {
    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Database error: {0}")]
    Database(#[from] rusqlite::Error),

    #[error("Walk error: {0}")]
    Walk(#[from] walkdir::Error),

    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),

    #[error("Scan cancelled")]
    Cancelled,

    #[error("{0}")]
    Other(String),
}

pub type Result<T> = std::result::Result<T, DeDupoError>;

/// Phases of the scanning pipeline.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[repr(i32)]
pub enum ScanPhase {
    /// Enumerating files and collecting metadata
    Enumerating = 0,
    /// Layer 0: Grouping by file size
    SizeGrouping = 1,
    /// Layer 1: Hashing first 4KB
    HeadHashing = 2,
    /// Layer 2: Hashing last 4KB
    TailHashing = 3,
    /// Layer 3: Full file hashing
    FullHashing = 4,
    /// Scan complete
    Complete = 5,
}

/// Represents a single file entry with its metadata and hashes.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileEntry {
    pub path: String,
    pub size: u64,
    pub modified_at: i64,
    pub head_hash: Option<String>,
    pub tail_hash: Option<String>,
    pub full_hash: Option<String>,
    pub volume_id: Option<String>,
}

/// A group of duplicate files sharing the same content hash.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DuplicateGroup {
    pub group_hash: String,
    pub file_size: u64,
    pub files: Vec<DuplicateFile>,
}

impl DuplicateGroup {
    /// Total wasted space: (file_count - 1) * file_size
    pub fn wasted_space(&self) -> u64 {
        if self.files.len() <= 1 {
            return 0;
        }
        (self.files.len() as u64 - 1) * self.file_size
    }
}

/// A single file within a duplicate group.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DuplicateFile {
    pub path: String,
    pub is_kept: bool,
    pub volume_name: Option<String>,
}

/// Progress information reported during a scan.
#[derive(Debug, Clone)]
pub struct ScanProgress {
    pub scanned_count: u64,
    pub total_estimated: u64,
    pub phase: ScanPhase,
}

/// Configuration for a scan operation.
#[derive(Debug, Clone)]
pub struct ScanConfig {
    pub paths: Vec<String>,
    pub head_hash_bytes: usize,
    pub tail_hash_bytes: usize,
}

impl Default for ScanConfig {
    fn default() -> Self {
        Self {
            paths: Vec::new(),
            head_hash_bytes: 4096, // 4KB
            tail_hash_bytes: 4096, // 4KB
        }
    }
}
