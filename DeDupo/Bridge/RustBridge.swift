import Foundation

/// Scan phase reported by the Rust engine, mirroring `ScanPhase` in types.rs.
enum ScanPhase: Int32 {
    case enumerating = 0
    case sizeGrouping = 1
    case headHashing = 2
    case tailHashing = 3
    case fullHashing = 4
    case complete = 5

    var description: String {
        switch self {
        case .enumerating: return "Enumerating files..."
        case .sizeGrouping: return "Grouping by file size..."
        case .headHashing: return "Hashing file headers..."
        case .tailHashing: return "Hashing file tails..."
        case .fullHashing: return "Computing full hashes..."
        case .complete: return "Scan complete"
        }
    }
}

/// Swift wrapper around the Rust deduplication engine.
///
/// Manages the lifecycle of the Rust `Engine` instance and provides
/// a safe, idiomatic Swift API over the raw FFI calls.
final class RustEngine: @unchecked Sendable {
    private let engine: OpaquePointer

    /// Create a new engine with a database at the given path.
    init?(dbPath: String) {
        guard let ptr = dbPath.withCString({ dedupo_engine_create($0) }) else {
            return nil
        }
        self.engine = ptr
    }

    deinit {
        dedupo_engine_free(engine)
    }

    /// Add a directory to the scan target list.
    func addScanPath(_ path: String) {
        path.withCString { dedupo_add_scan_path(engine, $0) }
    }

    /// Start an asynchronous scan with progress reporting.
    ///
    /// - Parameter onProgress: Called with (scannedCount, totalEstimated, phase).
    /// - Returns: 0 on success, 1 if cancelled, -1 on error.
    @discardableResult
    func startScan(onProgress: @escaping (UInt64, UInt64, ScanPhase) -> Void) -> Int32 {
        // Box the closure and pass it as the context pointer
        let context = Unmanaged.passRetained(
            ProgressCallbackBox(callback: onProgress)
        ).toOpaque()

        let result = dedupo_scan_start(engine, progressTrampoline, context)

        // Release the context
        Unmanaged<ProgressCallbackBox>.fromOpaque(context).release()

        return result
    }

    /// Cancel an ongoing scan.
    func cancelScan() {
        dedupo_scan_cancel(engine)
    }

    /// Get the number of duplicate groups found.
    var groupCount: UInt64 {
        dedupo_get_group_count(engine)
    }

    /// Retrieve all duplicate groups as decoded Swift models.
    func getGroups() -> [DuplicateGroup] {
        var groups: [DuplicateGroup] = []
        let count = groupCount

        for i in 0..<count {
            guard let cStr = dedupo_get_group(engine, i) else { continue }
            defer { dedupo_free_string(cStr) }

            let json = String(cString: cStr)
            if let data = json.data(using: .utf8),
               let group = try? JSONDecoder().decode(DuplicateGroup.self, from: data) {
                groups.append(group)
            }
        }

        return groups
    }
}

// MARK: - Callback Bridging

/// Box wrapping a Swift closure for passage through C void pointer.
private class ProgressCallbackBox {
    let callback: (UInt64, UInt64, ScanPhase) -> Void

    init(callback: @escaping (UInt64, UInt64, ScanPhase) -> Void) {
        self.callback = callback
    }
}

/// C-compatible trampoline function that forwards to the Swift closure.
private func progressTrampoline(
    scannedCount: UInt64,
    totalEstimated: UInt64,
    phase: Int32,
    context: UnsafeMutableRawPointer?
) {
    guard let context else { return }
    let box_ = Unmanaged<ProgressCallbackBox>.fromOpaque(context)
        .takeUnretainedValue()
    let scanPhase = ScanPhase(rawValue: phase) ?? .enumerating
    box_.callback(scannedCount, totalEstimated, scanPhase)
}
