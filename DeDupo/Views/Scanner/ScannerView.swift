import SwiftUI

/// View for configuring and starting a deduplication scan.
struct ScannerView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = ScannerViewModel()
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
        .onChange(of: viewModel.scanCompleted) { _, completed in
            if completed {
                appState.selectedNavigation = .results
            }
        }
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

        // Start button
        Button {
            viewModel.startScan(engine: appState.engine)
        } label: {
            Label("Start Scan", systemImage: "play.fill")
                .frame(maxWidth: 200)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(viewModel.scanTargets.isEmpty)

        // Error display
        if let error = viewModel.errorMessage {
            Text(error)
                .foregroundStyle(.red)
                .font(.caption)
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
