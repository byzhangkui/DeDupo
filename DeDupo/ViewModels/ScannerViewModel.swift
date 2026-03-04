import SwiftUI

private let targetsKey = "scanTargetPaths"
private let scannedPathsKey = "scannedPaths"

/// ViewModel for the scanner view — manages scan targets and scan execution.
@Observable
@MainActor
final class ScannerViewModel {
    /// Directories selected for scanning.
    var scanTargets: [ScanTarget] = []

    /// Paths that have already been scanned (persisted across launches).
    var scannedPaths: Set<String> = []

    /// Whether a scan is currently running.
    var isScanning = false

    /// Whether the last scan was incremental.
    var isIncrementalScan = false

    /// Current scan phase description.
    var phaseDescription = ""

    /// Number of files scanned so far.
    var scannedCount: UInt64 = 0

    /// Estimated total number of files.
    var totalEstimated: UInt64 = 0

    /// Progress value (0.0 to 1.0).
    var progress: Double {
        guard totalEstimated > 0 else { return 0 }
        return Double(scannedCount) / Double(totalEstimated)
    }

    /// Error message if scan failed.
    var errorMessage: String?

    /// Whether the scan completed successfully.
    var scanCompleted = false

    /// Targets not yet scanned.
    var newTargets: [ScanTarget] {
        scanTargets.filter { !scannedPaths.contains($0.path) }
    }

    /// Whether there are new (unscanned) targets.
    var hasNewTargets: Bool { !newTargets.isEmpty }

    /// Whether any target has been scanned before.
    var hasScannedTargets: Bool { !scannedPaths.isEmpty }

    init() {
        loadPersistedState()
    }

    // MARK: - Persistence

    private func loadPersistedState() {
        let defaults = UserDefaults.standard
        if let paths = defaults.stringArray(forKey: targetsKey) {
            scanTargets = paths.compactMap { path -> ScanTarget? in
                let url = URL(fileURLWithPath: path)
                return ScanTarget(url: url)
            }
        }
        if let paths = defaults.stringArray(forKey: scannedPathsKey) {
            scannedPaths = Set(paths)
        }
    }

    private func persistTargets() {
        UserDefaults.standard.set(scanTargets.map(\.path), forKey: targetsKey)
    }

    private func persistScannedPaths() {
        UserDefaults.standard.set(Array(scannedPaths), forKey: scannedPathsKey)
    }

    // MARK: - Target Management

    /// Add a directory URL as a scan target.
    func addTarget(_ url: URL) {
        let path = url.path
        guard !scanTargets.contains(where: { $0.path == path }) else { return }
        scanTargets.append(ScanTarget(url: url))
        persistTargets()
    }

    /// Remove a scan target.
    func removeTarget(_ target: ScanTarget) {
        scanTargets.removeAll { $0.id == target.id }
        scannedPaths.remove(target.path)
        persistTargets()
        persistScannedPaths()
    }

    // MARK: - Scanning

    /// Start a full scan of all targets using the Rust engine.
    func startScan(engine: RustEngine?) {
        guard let engine, !scanTargets.isEmpty else {
            if engine == nil { errorMessage = "Engine not initialized" }
            return
        }

        isScanning = true
        isIncrementalScan = false
        scanCompleted = false
        errorMessage = nil
        scannedCount = 0
        totalEstimated = 0

        engine.clearScanPaths()
        for target in scanTargets {
            engine.addScanPath(target.path)
        }

        Task.detached { [engine] in
            let result = engine.startScan { scanned, total, phase in
                Task { @MainActor [weak self] in
                    self?.scannedCount = scanned
                    self?.totalEstimated = total
                    self?.phaseDescription = phase.description
                }
            }

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isScanning = false
                if result == 0 {
                    self.scannedPaths = Set(self.scanTargets.map(\.path))
                    self.persistScannedPaths()
                    self.scanCompleted = true
                } else if result == 1 {
                    self.phaseDescription = "Scan cancelled"
                } else {
                    self.errorMessage = "Scan failed"
                }
            }
        }
    }

    /// Start an incremental scan of only new (unscanned) targets.
    func startIncrementalScan(engine: RustEngine?) {
        guard let engine, !newTargets.isEmpty else { return }

        isScanning = true
        isIncrementalScan = true
        scanCompleted = false
        errorMessage = nil
        scannedCount = 0
        totalEstimated = 0

        let targets = newTargets
        engine.clearScanPaths()
        for target in targets {
            engine.addScanPath(target.path)
        }

        Task.detached { [engine] in
            let result = engine.startScan { scanned, total, phase in
                Task { @MainActor [weak self] in
                    self?.scannedCount = scanned
                    self?.totalEstimated = total
                    self?.phaseDescription = phase.description
                }
            }

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isScanning = false
                if result == 0 {
                    for target in targets {
                        self.scannedPaths.insert(target.path)
                    }
                    self.persistScannedPaths()
                    self.scanCompleted = true
                } else if result == 1 {
                    self.phaseDescription = "Scan cancelled"
                } else {
                    self.errorMessage = "Scan failed"
                }
            }
        }
    }

    /// Cancel the current scan.
    func cancelScan(engine: RustEngine?) {
        engine?.cancelScan()
    }
}
