import Foundation

/// A group of files that share the same content hash.
struct DuplicateGroup: Identifiable, Codable {
    let id = UUID()
    let groupHash: String
    let fileSize: UInt64
    var files: [DuplicateFile]

    /// Total wasted space: (count - 1) * fileSize
    var wastedSpace: UInt64 {
        guard files.count > 1 else { return 0 }
        return UInt64(files.count - 1) * fileSize
    }

    /// Human-readable wasted space string.
    var formattedWastedSpace: String {
        ByteCountFormatter.string(fromByteCount: Int64(wastedSpace), countStyle: .file)
    }

    /// Human-readable file size string.
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }

    enum CodingKeys: String, CodingKey {
        case groupHash = "group_hash"
        case fileSize = "file_size"
        case files
    }
}
