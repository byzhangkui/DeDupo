import Foundation

/// Service for safely moving files to the system trash.
enum TrashService {
    /// Move a file to the macOS Trash.
    ///
    /// Uses NSFileManager's trashItem which provides undo support
    /// and moves to the correct per-volume .Trashes directory.
    ///
    /// - Parameter path: Absolute path to the file.
    /// - Returns: The URL of the item in the trash, or nil on failure.
    @discardableResult
    static func moveToTrash(path: String) -> URL? {
        let url = URL(fileURLWithPath: path)
        var resultURL: NSURL?

        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: &resultURL)
            return resultURL as URL?
        } catch {
            // Log the error but don't crash — the UI should handle failures gracefully
            print("Failed to trash \(path): \(error.localizedDescription)")
            return nil
        }
    }

    /// Move multiple files to the trash.
    ///
    /// - Parameter paths: List of absolute file paths.
    /// - Returns: Number of files successfully trashed.
    static func moveToTrash(paths: [String]) -> Int {
        var successCount = 0
        for path in paths {
            if moveToTrash(path: path) != nil {
                successCount += 1
            }
        }
        return successCount
    }
}
