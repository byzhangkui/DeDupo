use dedupo_core::Engine;
use std::fs::{self, File};
use std::io::Write;
use std::path::PathBuf;
use tempfile::tempdir;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // 1. Create a temporary directory for testing
    let dir = tempdir()?;
    let path = dir.path();
    println!("Created temporary directory for testing: {:?}", path);

    // 2. Create some duplicate files
    let content1 = b"Hello, world! This is a duplicate file.";
    let content2 = b"Another duplicate file with different content.";

    // Group 1
    fs::write(path.join("file1.txt"), content1)?;
    fs::write(path.join("file2.txt"), content1)?;
    fs::write(path.join("file3.txt"), content1)?;

    // Group 2
    fs::write(path.join("file4.txt"), content2)?;
    fs::write(path.join("file5.txt"), content2)?;

    // A unique file
    fs::write(path.join("unique.txt"), b"I am unique!")?;

    // Create a subdirectory with a duplicate
    let sub = path.join("subdir");
    fs::create_dir(&sub)?;
    fs::write(sub.join("file1_copy.txt"), content1)?;

    // 3. Initialize the Engine
    let db_path = path.join("dedupo_test.db");
    let mut engine = Engine::new(db_path.to_str().unwrap())?;

    // 4. Set scan paths
    engine.add_scan_path(path.to_str().unwrap());

    // 5. Run the scan
    println!("Starting scan...");
    engine.scan(|progress| {
        println!("Progress: Phase={:?}, Scanned={}/{}", 
            progress.phase, progress.scanned_count, progress.total_estimated);
    })?;

    // 6. Check results
    let count = engine.group_count();
    println!("Scan complete! Found {} duplicate groups.", count);

    for i in 0..count {
        if let Some(json) = engine.get_group_json(i) {
            println!("Group {}: {}", i, json);
        }
    }

    Ok(())
}
