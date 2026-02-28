import SwiftUI

/// ViewModel for the scanner view — manages scan targets and scan execution.
@Observable
@MainActor
final class ScannerViewModel {
    /// Directories selected for scanning.
    var scanTargets: [ScanTarget] = []

    /// Whether a scan is currently running.
    var isScanning = false

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

    /// Add a directory URL as a scan target.
    func addTarget(_ url: URL) {
        let target = ScanTarget(url: url)
        guard !scanTargets.contains(target) else { return }
        scanTargets.append(target)
    }

    /// Remove a scan target.
    func removeTarget(_ target: ScanTarget) {
        scanTargets.removeAll { $0.id == target.id }
    }

    /// Start the scan using the Rust engine.
    func startScan(engine: RustEngine?) {
        guard let engine, !scanTargets.isEmpty else { return }

        isScanning = true
        scanCompleted = false
        errorMessage = nil
        scannedCount = 0
        totalEstimated = 0

        // Add all target paths to the engine
        for target in scanTargets {
            engine.addScanPath(target.path)
        }

        // Run scan on a background thread
        Task.detached { [engine] in
            let result = engine.startScan { scanned, total, phase in
                Task { @MainActor [weak self] in
                    self?.scannedCount = scanned
                    self?.totalEstimated = total
                    self?.phaseDescription = phase.description
                }
            }

            await MainActor.run { [weak self] in
                self?.isScanning = false
                if result == 0 {
                    self?.scanCompleted = true
                } else if result == 1 {
                    self?.phaseDescription = "Scan cancelled"
                } else {
                    self?.errorMessage = "Scan failed"
                }
            }
        }
    }

    /// Cancel the current scan.
    func cancelScan(engine: RustEngine?) {
        engine?.cancelScan()
    }
}
