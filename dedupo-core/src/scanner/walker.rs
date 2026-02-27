use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::UNIX_EPOCH;

use walkdir::WalkDir;

use crate::types::{FileEntry, Result};
use super::filter;

/// Recursively walk a directory and collect file entries.
///
/// Skips:
/// - Directories (only files are collected)
/// - Symlinks (to avoid counting the same file twice)
/// - System/hidden paths that should be excluded
pub fn walk_directory(
    root: &str,
    cancelled: &Arc<AtomicBool>,
) -> Result<Vec<FileEntry>> {
    let mut files = Vec::new();

    for entry in WalkDir::new(root)
        .follow_links(false)
        .into_iter()
        .filter_entry(|e| !filter::should_skip(e))
    {
        if cancelled.load(Ordering::Relaxed) {
            return Err(crate::types::DeDupoError::Cancelled);
        }

        let entry = match entry {
            Ok(e) => e,
            Err(e) => {
                log::warn!("Walk error: {}", e);
                continue;
            }
        };

        // Only process regular files
        if !entry.file_type().is_file() {
            continue;
        }

        let metadata = match entry.metadata() {
            Ok(m) => m,
            Err(e) => {
                log::warn!("Metadata error for {:?}: {}", entry.path(), e);
                continue;
            }
        };

        // Skip empty files — they're trivially "duplicates"
        if metadata.len() == 0 {
            continue;
        }

        let modified_at = metadata
            .modified()
            .ok()
            .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
            .map(|d| d.as_secs() as i64)
            .unwrap_or(0);

        files.push(FileEntry {
            path: entry.path().to_string_lossy().to_string(),
            size: metadata.len(),
            modified_at,
            head_hash: None,
            tail_hash: None,
            full_hash: None,
            volume_id: None,
        });
    }

    Ok(files)
}
