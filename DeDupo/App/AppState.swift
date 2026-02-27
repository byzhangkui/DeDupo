import SwiftUI

/// Global application state shared across all views.
@Observable
final class AppState {
    /// The Rust engine bridge instance.
    var engine: RustEngine?

    /// Currently selected sidebar navigation item.
    var selectedNavigation: NavigationItem = .scanner

    /// Whether a scan is currently in progress.
    var isScanning: Bool = false

    /// Available mounted volumes detected by VolumeMonitor.
    var mountedVolumes: [VolumeInfo] = []

    init() {
        // Initialize the Rust engine with a database in Application Support
        let dbPath = Self.databasePath()
        engine = RustEngine(dbPath: dbPath)
    }

    /// Path to the SQLite database in Application Support.
    private static func databasePath() -> String {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!.appendingPathComponent("DeDupo", isDirectory: true)

        try? FileManager.default.createDirectory(
            at: appSupport,
            withIntermediateDirectories: true
        )

        return appSupport.appendingPathComponent("dedupo.db").path
    }
}

/// Sidebar navigation items.
enum NavigationItem: String, CaseIterable, Identifiable {
    case scanner = "Scanner"
    case results = "Results"
    case settings = "Settings"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .scanner: return "folder.badge.gearshape"
        case .results: return "chart.bar.doc.horizontal"
        case .settings: return "gearshape"
        }
    }
}

/// Information about a mounted volume.
struct VolumeInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
    let isExternal: Bool
}
