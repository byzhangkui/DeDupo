use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use rayon::prelude::*;

use super::blake3_hash;
use crate::types::{DeDupoError, FileEntry, Result};

/// Hash the first `n` bytes of each file entry (Layer 1).
///
/// Uses rayon for parallel processing. Entries that fail to hash are
/// logged and skipped.
pub fn hash_heads(
    entries: &[FileEntry],
    head_bytes: usize,
    cancelled: &Arc<AtomicBool>,
) -> Result<Vec<FileEntry>> {
    if cancelled.load(Ordering::SeqCst) {
        return Err(DeDupoError::Cancelled);
    }

    let results: Vec<FileEntry> = entries
        .par_iter()
        .filter_map(|entry| {
            if cancelled.load(Ordering::Relaxed) {
                return None;
            }
            match blake3_hash::hash_head(&entry.path, head_bytes) {
                Ok(hash) => {
                    let mut e = entry.clone();
                    e.head_hash = Some(hash);
                    Some(e)
                }
                Err(e) => {
                    log::warn!("Head hash failed for {}: {}", entry.path, e);
                    None
                }
            }
        })
        .collect();

    Ok(results)
}

/// Hash the last `n` bytes of each file entry (Layer 2).
pub fn hash_tails(
    entries: &[FileEntry],
    tail_bytes: usize,
    cancelled: &Arc<AtomicBool>,
) -> Result<Vec<FileEntry>> {
    if cancelled.load(Ordering::SeqCst) {
        return Err(DeDupoError::Cancelled);
    }

    let results: Vec<FileEntry> = entries
        .par_iter()
        .filter_map(|entry| {
            if cancelled.load(Ordering::Relaxed) {
                return None;
            }
            match blake3_hash::hash_tail(&entry.path, tail_bytes) {
                Ok(hash) => {
                    let mut e = entry.clone();
                    e.tail_hash = Some(hash);
                    Some(e)
                }
                Err(e) => {
                    log::warn!("Tail hash failed for {}: {}", entry.path, e);
                    None
                }
            }
        })
        .collect();

    Ok(results)
}

/// Hash entire files using BLAKE3 (Layer 3).
///
/// This is the most I/O-intensive operation and is only performed on
/// the small percentage of files that survived all previous layers.
pub fn hash_full(
    entries: &[FileEntry],
    cancelled: &Arc<AtomicBool>,
) -> Result<Vec<FileEntry>> {
    if cancelled.load(Ordering::SeqCst) {
        return Err(DeDupoError::Cancelled);
    }

    let results: Vec<FileEntry> = entries
        .par_iter()
        .filter_map(|entry| {
            if cancelled.load(Ordering::Relaxed) {
                return None;
            }
            match blake3_hash::hash_full(&entry.path) {
                Ok(hash) => {
                    let mut e = entry.clone();
                    e.full_hash = Some(hash);
                    Some(e)
                }
                Err(e) => {
                    log::warn!("Full hash failed for {}: {}", entry.path, e);
                    None
                }
            }
        })
        .collect();

    Ok(results)
}
