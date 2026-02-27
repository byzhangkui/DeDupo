use rusqlite::Connection;

use crate::types::{DuplicateGroup, Result};

const SCHEMA: &str = include_str!("schema.sql");

/// SQLite database wrapper for DeDupo persistence.
pub struct Database {
    conn: Connection,
}

impl Database {
    /// Open (or create) a database at the given path.
    pub fn open(path: &str) -> Result<Self> {
        let conn = Connection::open(path)?;

        // Enable WAL mode for better concurrent read performance
        conn.execute_batch("PRAGMA journal_mode=WAL;")?;
        conn.execute_batch("PRAGMA foreign_keys=ON;")?;

        Ok(Self { conn })
    }

    /// Initialize the database schema (idempotent).
    pub fn initialize(&self) -> Result<()> {
        self.conn.execute_batch(SCHEMA)?;
        Ok(())
    }

    /// Record the start of a new scan and return the scan ID.
    pub fn start_scan(&self, scan_paths: &[String]) -> Result<i64> {
        let paths_json = serde_json::to_string(scan_paths)?;
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs() as i64;

        self.conn.execute(
            "INSERT INTO scan_history (started_at, scan_paths) VALUES (?1, ?2)",
            rusqlite::params![now, paths_json],
        )?;

        Ok(self.conn.last_insert_rowid())
    }

    /// Record the completion of a scan with summary statistics.
    pub fn finish_scan(
        &self,
        scan_id: i64,
        total_files: u64,
        total_size: u64,
        duplicates: u64,
        saved_space: u64,
    ) -> Result<()> {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs() as i64;

        self.conn.execute(
            "UPDATE scan_history SET finished_at=?1, total_files=?2, total_size=?3, duplicates=?4, saved_space=?5 WHERE id=?6",
            rusqlite::params![now, total_files as i64, total_size as i64, duplicates as i64, saved_space as i64, scan_id],
        )?;

        Ok(())
    }

    /// Save duplicate groups to the database for a given scan.
    pub fn save_duplicate_groups(
        &self,
        scan_id: i64,
        groups: &[DuplicateGroup],
    ) -> Result<()> {
        let tx = self.conn.unchecked_transaction()?;

        for group in groups {
            tx.execute(
                "INSERT INTO duplicate_groups (scan_id, group_hash, file_count, file_size, wasted_space) VALUES (?1, ?2, ?3, ?4, ?5)",
                rusqlite::params![
                    scan_id,
                    group.group_hash,
                    group.files.len() as i64,
                    group.file_size as i64,
                    group.wasted_space() as i64,
                ],
            )?;

            let group_id = tx.last_insert_rowid();

            for file in &group.files {
                tx.execute(
                    "INSERT INTO duplicate_files (group_id, file_path, is_kept, volume_name) VALUES (?1, ?2, ?3, ?4)",
                    rusqlite::params![
                        group_id,
                        file.path,
                        file.is_kept,
                        file.volume_name,
                    ],
                )?;
            }
        }

        tx.commit()?;
        Ok(())
    }

    /// Update a file index entry with hash information.
    pub fn upsert_file_index(
        &self,
        path: &str,
        size: u64,
        modified_at: i64,
        head_hash: Option<&str>,
        tail_hash: Option<&str>,
        full_hash: Option<&str>,
        volume_id: Option<&str>,
    ) -> Result<()> {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs() as i64;

        self.conn.execute(
            "INSERT INTO file_index (path, size, modified_at, head_hash, tail_hash, full_hash, last_scanned, volume_id)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
             ON CONFLICT(path) DO UPDATE SET
                size=excluded.size,
                modified_at=excluded.modified_at,
                head_hash=excluded.head_hash,
                tail_hash=excluded.tail_hash,
                full_hash=excluded.full_hash,
                last_scanned=excluded.last_scanned,
                volume_id=excluded.volume_id",
            rusqlite::params![path, size as i64, modified_at, head_hash, tail_hash, full_hash, now, volume_id],
        )?;

        Ok(())
    }
}
