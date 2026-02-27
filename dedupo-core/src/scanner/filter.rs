use walkdir::DirEntry;

/// System directories that should always be skipped during scanning.
const SKIP_DIRS: &[&str] = &[
    ".Trash",
    ".Trashes",
    ".Spotlight-V100",
    ".fseventsd",
    ".TemporaryItems",
    ".DocumentRevisions-V100",
    ".DS_Store",
    "node_modules",
    ".git",
    "__pycache__",
];

/// Determine if a directory entry should be skipped.
///
/// Returns `true` if the entry is a known system directory or hidden
/// path that should not be traversed.
pub fn should_skip(entry: &DirEntry) -> bool {
    let file_name = entry.file_name().to_string_lossy();

    // Skip known system/cache directories
    if entry.file_type().is_dir() {
        if SKIP_DIRS.iter().any(|&d| file_name == d) {
            return true;
        }
    }

    false
}
