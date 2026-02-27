import Foundation

/// A directory selected by the user as a scan target.
struct ScanTarget: Identifiable, Hashable {
    let id = UUID()
    let url: URL

    var path: String { url.path }
    var displayName: String { url.lastPathComponent }

    /// Whether this target points to an external volume.
    var isExternalVolume: Bool {
        url.path.hasPrefix("/Volumes/")
    }
}
