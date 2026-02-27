pub mod filter;
pub mod walker;

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use crate::types::{FileEntry, Result};

/// Walk all given directories and collect file entries.
///
/// Respects the cancellation flag and skips files that don't pass filtering.
pub fn walk_directories(
    paths: &[String],
    cancelled: &Arc<AtomicBool>,
) -> Result<Vec<FileEntry>> {
    let mut all_files = Vec::new();

    for path in paths {
        if cancelled.load(Ordering::SeqCst) {
            return Err(crate::types::DeDupoError::Cancelled);
        }

        let files = walker::walk_directory(path, cancelled)?;
        all_files.extend(files);
    }

    Ok(all_files)
}
