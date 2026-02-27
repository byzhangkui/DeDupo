use std::fs::File;
use std::io::{Read, Seek, SeekFrom};

use crate::types::Result;

/// Hash the first `n` bytes of a file using BLAKE3.
pub fn hash_head(path: &str, n: usize) -> Result<String> {
    let mut file = File::open(path)?;
    let mut buffer = vec![0u8; n];
    let bytes_read = file.read(&mut buffer)?;
    buffer.truncate(bytes_read);

    let hash = blake3::hash(&buffer);
    Ok(hash.to_hex().to_string())
}

/// Hash the last `n` bytes of a file using BLAKE3.
pub fn hash_tail(path: &str, n: usize) -> Result<String> {
    let mut file = File::open(path)?;
    let file_len = file.metadata()?.len();

    let offset = if file_len > n as u64 {
        file_len - n as u64
    } else {
        0
    };

    file.seek(SeekFrom::Start(offset))?;
    let mut buffer = vec![0u8; n];
    let bytes_read = file.read(&mut buffer)?;
    buffer.truncate(bytes_read);

    let hash = blake3::hash(&buffer);
    Ok(hash.to_hex().to_string())
}

/// Hash an entire file using BLAKE3 with streaming reads.
///
/// Uses a 64KB buffer for memory-efficient processing of large files.
pub fn hash_full(path: &str) -> Result<String> {
    let mut file = File::open(path)?;
    let mut hasher = blake3::Hasher::new();

    let mut buffer = [0u8; 65536]; // 64KB buffer
    loop {
        let bytes_read = file.read(&mut buffer)?;
        if bytes_read == 0 {
            break;
        }
        hasher.update(&buffer[..bytes_read]);
    }

    let hash = hasher.finalize();
    Ok(hash.to_hex().to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use tempfile::NamedTempFile;

    fn create_temp_file(content: &[u8]) -> NamedTempFile {
        let mut f = NamedTempFile::new().unwrap();
        f.write_all(content).unwrap();
        f.flush().unwrap();
        f
    }

    #[test]
    fn test_hash_consistency() {
        let content = b"Hello, DeDupo!";
        let f = create_temp_file(content);
        let path = f.path().to_str().unwrap();

        let h1 = hash_full(path).unwrap();
        let h2 = hash_full(path).unwrap();
        assert_eq!(h1, h2, "Same file should produce same hash");
    }

    #[test]
    fn test_different_content_different_hash() {
        let f1 = create_temp_file(b"content A");
        let f2 = create_temp_file(b"content B");

        let h1 = hash_full(f1.path().to_str().unwrap()).unwrap();
        let h2 = hash_full(f2.path().to_str().unwrap()).unwrap();
        assert_ne!(h1, h2, "Different content should produce different hash");
    }

    #[test]
    fn test_head_hash_small_file() {
        let content = b"short";
        let f = create_temp_file(content);
        let path = f.path().to_str().unwrap();

        // Requesting more bytes than file size should still work
        let h = hash_head(path, 4096).unwrap();
        assert!(!h.is_empty());
    }
}
