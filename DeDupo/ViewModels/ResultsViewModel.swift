import SwiftUI

/// Sort options for duplicate groups.
enum SortOption: String, CaseIterable, Identifiable {
    case size = "File Size"
    case wastedSpace = "Wasted Space"
    case fileCount = "File Count"

    var id: String { rawValue }
}

/// ViewModel for the results view — manages duplicate group display and actions.
@Observable
final class ResultsViewModel {
    /// All duplicate groups from the last scan.
    var groups: [DuplicateGroup] = []

    /// Current sort order.
    var sortBy: SortOption = .wastedSpace

    /// Whether sorted descending.
    var sortDescending = true

    /// Total wasted space across all groups.
    var totalWastedSpace: UInt64 {
        groups.reduce(0) { $0 + $1.wastedSpace }
    }

    /// Human-readable total wasted space.
    var formattedTotalWasted: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalWastedSpace), countStyle: .file)
    }

    /// Sorted groups based on current sort settings.
    var sortedGroups: [DuplicateGroup] {
        let sorted: [DuplicateGroup]
        switch sortBy {
        case .size:
            sorted = groups.sorted { $0.fileSize < $1.fileSize }
        case .wastedSpace:
            sorted = groups.sorted { $0.wastedSpace < $1.wastedSpace }
        case .fileCount:
            sorted = groups.sorted { $0.files.count < $1.files.count }
        }
        return sortDescending ? sorted.reversed() : sorted
    }

    // MARK: - Persistence

    private static var saveURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("DeDupo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("last_scan.json")
    }

    func saveResults() {
        do {
            let data = try JSONEncoder().encode(groups)
            try data.write(to: Self.saveURL, options: .atomic)
        } catch {
            // Non-fatal: persistence failure doesn't affect current session
        }
    }

    func loadSavedResults() {
        guard groups.isEmpty else { return }
        guard let data = try? Data(contentsOf: Self.saveURL) else { return }
        if let saved = try? JSONDecoder().decode([DuplicateGroup].self, from: data) {
            groups = saved
        }
    }

    // MARK: - Loading

    /// Load results from the Rust engine.
    func loadResults(engine: RustEngine?) {
        guard let engine else { return }
        groups = engine.getGroups()
    }

    /// Merge incremental scan results into existing groups.
    func mergeResults(_ newGroups: [DuplicateGroup]) {
        // Build a lookup from groupHash to index in existing groups
        var hashToIndex: [String: Int] = [:]
        for (i, group) in groups.enumerated() {
            hashToIndex[group.groupHash] = i
        }

        for newGroup in newGroups {
            if let idx = hashToIndex[newGroup.groupHash] {
                // Merge new files into existing group (avoid duplicates by path)
                let existingPaths = Set(groups[idx].files.map(\.path))
                let filesToAdd = newGroup.files.filter { !existingPaths.contains($0.path) }
                groups[idx].files.append(contentsOf: filesToAdd)
            } else {
                groups.append(newGroup)
            }
        }
    }

    // MARK: - Actions

    /// Toggle the kept status of a file in a group.
    func toggleKept(groupIndex: Int, fileIndex: Int) {
        guard groupIndex < groups.count,
              fileIndex < groups[groupIndex].files.count else { return }
        groups[groupIndex].files[fileIndex].isKept.toggle()
    }

    /// Get files marked for deletion (not kept) across all groups.
    var filesToDelete: [DuplicateFile] {
        groups.flatMap { group in
            group.files.filter { !$0.isKept }
        }
    }

    /// Space that would be recovered by deleting non-kept files.
    var spaceToRecover: UInt64 {
        groups.reduce(0) { total, group in
            let deleteCount = group.files.filter { !$0.isKept }.count
            return total + UInt64(deleteCount) * group.fileSize
        }
    }

    /// Remove successfully trashed files from the current groups.
    func removeDeletedFiles(paths: Set<String>) {
        for i in (0..<groups.count).reversed() {
            groups[i].files.removeAll { paths.contains($0.path) }
            if groups[i].files.count <= 1 {
                groups.remove(at: i)
            }
        }
    }
}
