import Foundation

/// A single file within a duplicate group.
struct DuplicateFile: Identifiable, Codable, Hashable {
    let id = UUID()
    let path: String
    var isKept: Bool
    let volumeName: String?

    /// Display name (filename only).
    var displayName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    /// Parent directory path.
    var directoryPath: String {
        URL(fileURLWithPath: path).deletingLastPathComponent().path
    }

    enum CodingKeys: String, CodingKey {
        case path
        case isKept = "is_kept"
        case volumeName = "volume_name"
    }
}
