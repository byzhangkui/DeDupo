use std::collections::HashMap;

use crate::types::{DuplicateFile, DuplicateGroup, FileEntry};

/// Layer 0: Group files by size.
///
/// Files with a unique size cannot be duplicates and are eliminated.
/// This is the cheapest filter — zero I/O, metadata only.
pub fn group_by_size(files: Vec<FileEntry>) -> HashMap<u64, Vec<FileEntry>> {
    let mut groups: HashMap<u64, Vec<FileEntry>> = HashMap::new();
    for file in files {
        groups.entry(file.size).or_default().push(file);
    }
    groups
}

/// Layer 1: Group files by head hash.
///
/// Files with the same size but different head hashes are eliminated.
pub fn group_by_head_hash(files: Vec<FileEntry>) -> HashMap<String, Vec<FileEntry>> {
    let mut groups: HashMap<String, Vec<FileEntry>> = HashMap::new();
    for file in files {
        if let Some(ref hash) = file.head_hash {
            groups.entry(hash.clone()).or_default().push(file);
        }
    }
    groups
}

/// Layer 2: Group files by tail hash.
///
/// Files with the same head hash but different tail hashes are eliminated.
pub fn group_by_tail_hash(files: Vec<FileEntry>) -> HashMap<String, Vec<FileEntry>> {
    let mut groups: HashMap<String, Vec<FileEntry>> = HashMap::new();
    for file in files {
        if let Some(ref hash) = file.tail_hash {
            groups.entry(hash.clone()).or_default().push(file);
        }
    }
    groups
}

/// Layer 3: Build final duplicate groups from fully-hashed files.
///
/// Files sharing the same full hash are confirmed duplicates.
/// Groups with only one file are discarded (no duplicates).
///
/// Within each group, the file with the oldest modification time is
/// marked as "kept" (smart retain suggestion).
pub fn build_duplicate_groups(files: Vec<FileEntry>) -> Vec<DuplicateGroup> {
    let mut hash_groups: HashMap<String, Vec<FileEntry>> = HashMap::new();

    for file in files {
        if let Some(ref hash) = file.full_hash {
            hash_groups.entry(hash.clone()).or_default().push(file);
        }
    }

    let mut groups: Vec<DuplicateGroup> = hash_groups
        .into_iter()
        .filter(|(_, files)| files.len() > 1)
        .map(|(hash, mut files)| {
            // Sort by modification time — oldest first
            files.sort_by_key(|f| f.modified_at);

            let file_size = files.first().map(|f| f.size).unwrap_or(0);

            let duplicate_files: Vec<DuplicateFile> = files
                .iter()
                .enumerate()
                .map(|(i, f)| DuplicateFile {
                    path: f.path.clone(),
                    is_kept: i == 0, // Keep the oldest file by default
                    volume_name: f.volume_id.clone(),
                })
                .collect();

            DuplicateGroup {
                group_hash: hash,
                file_size,
                files: duplicate_files,
            }
        })
        .collect();

    // Sort groups by wasted space (largest first)
    groups.sort_by(|a, b| b.wasted_space().cmp(&a.wasted_space()));

    groups
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_entry(path: &str, size: u64) -> FileEntry {
        FileEntry {
            path: path.to_string(),
            size,
            modified_at: 0,
            head_hash: None,
            tail_hash: None,
            full_hash: None,
            volume_id: None,
        }
    }

    #[test]
    fn test_group_by_size_eliminates_unique() {
        let files = vec![
            make_entry("/a.txt", 100),
            make_entry("/b.txt", 100),
            make_entry("/c.txt", 200), // unique size
        ];

        let groups = group_by_size(files);
        assert_eq!(groups.get(&100).unwrap().len(), 2);
        assert_eq!(groups.get(&200).unwrap().len(), 1);
    }

    #[test]
    fn test_build_duplicate_groups_keeps_oldest() {
        let files = vec![
            FileEntry {
                path: "/newer.txt".into(),
                size: 100,
                modified_at: 2000,
                head_hash: None,
                tail_hash: None,
                full_hash: Some("abc123".into()),
                volume_id: None,
            },
            FileEntry {
                path: "/oldest.txt".into(),
                size: 100,
                modified_at: 1000,
                head_hash: None,
                tail_hash: None,
                full_hash: Some("abc123".into()),
                volume_id: None,
            },
        ];

        let groups = build_duplicate_groups(files);
        assert_eq!(groups.len(), 1);
        assert_eq!(groups[0].files.len(), 2);
        // Oldest should be kept
        assert!(groups[0].files[0].is_kept);
        assert_eq!(groups[0].files[0].path, "/oldest.txt");
        assert!(!groups[0].files[1].is_kept);
    }
}
