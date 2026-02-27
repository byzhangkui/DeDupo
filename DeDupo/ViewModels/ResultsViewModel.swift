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

    /// Load results from the Rust engine.
    func loadResults(engine: RustEngine?) {
        guard let engine else { return }
        groups = engine.getGroups()
    }

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
}
