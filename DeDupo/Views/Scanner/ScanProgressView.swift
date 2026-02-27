import SwiftUI

/// View showing scan progress with phase description and file counts.
struct ScanProgressView: View {
    let viewModel: ScannerViewModel
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ProgressView(value: viewModel.progress) {
                Text(viewModel.phaseDescription)
                    .font(.headline)
            } currentValueLabel: {
                if viewModel.totalEstimated > 0 {
                    Text("\(viewModel.scannedCount) / \(viewModel.totalEstimated) files")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .progressViewStyle(.linear)
            .frame(maxWidth: 400)

            Button("Cancel") {
                viewModel.cancelScan(engine: appState.engine)
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .padding()
    }
}
