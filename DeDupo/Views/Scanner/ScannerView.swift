import SwiftUI

/// View for configuring and starting a deduplication scan.
struct ScannerView: View {
    @Environment(AppState.self) private var appState
    var viewModel: ScannerViewModel
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 20) {
            if viewModel.isScanning {
                ScanProgressView(viewModel: viewModel)
            } else {
                scanConfigView
            }
        }
        .padding()
        .navigationTitle("Scan for Duplicates")
    }

    // MARK: - Scan Configuration

    @ViewBuilder
    private var scanConfigView: some View {
        // Drop zone
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Drop folders here or click to select")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: [8])
                )
                .foregroundStyle(isTargeted ? .blue : .secondary)
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
        .onTapGesture {
            selectFolder()
        }

        // Target list
        if !viewModel.scanTargets.isEmpty {
            List {
                ForEach(viewModel.scanTargets) { target in
                    HStack {
                        Image(systemName: target.isExternalVolume ? "externaldrive" : "folder")
                        Text(target.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        // Status badge
                        if viewModel.scannedPaths.contains(target.path) {
                            Text("Scanned")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.2))
                                .foregroundStyle(.secondary)
                                .clipShape(Capsule())
                        } else if viewModel.hasScannedTargets {
                            Text("New")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                        Button {
                            viewModel.removeTarget(target)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 200)
        }

        // Scan buttons
        scanButtonsView

        // Error display
        if let error = viewModel.errorMessage {
            Text(error)
                .foregroundStyle(.red)
                .font(.caption)
        }
    }

    @ViewBuilder
    private var scanButtonsView: some View {
        let hasScanned = viewModel.hasScannedTargets
        let hasNew = viewModel.hasNewTargets
        let empty = viewModel.scanTargets.isEmpty

        if hasScanned && hasNew {
            // Show primary "Scan New Folders" + secondary "Full Rescan"
            VStack(spacing: 8) {
                Button {
                    viewModel.startIncrementalScan(engine: appState.engine)
                } label: {
                    Label("Scan New Folders", systemImage: "plus.magnifyingglass")
                        .frame(maxWidth: 220)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    viewModel.startScan(engine: appState.engine)
                } label: {
                    Label("Full Rescan", systemImage: "arrow.clockwise")
                        .frame(maxWidth: 220)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        } else if hasScanned && !hasNew {
            // Only "Full Rescan" available
            Button {
                viewModel.startScan(engine: appState.engine)
            } label: {
                Label("Full Rescan", systemImage: "arrow.clockwise")
                    .frame(maxWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(empty)
        } else {
            // No previous scan — standard "Start Scan"
            Button {
                viewModel.startScan(engine: appState.engine)
            } label: {
                Label("Start Scan", systemImage: "play.fill")
                    .frame(maxWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(empty)
        }
    }

    // MARK: - Actions

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.message = "Select folders to scan for duplicates"

        if panel.runModal() == .OK {
            for url in panel.urls {
                viewModel.addTarget(url)
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url") { data, _ in
                guard let data = data as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      url.hasDirectoryPath else { return }

                Task { @MainActor in
                    viewModel.addTarget(url)
                }
            }
        }
        return true
    }
}
