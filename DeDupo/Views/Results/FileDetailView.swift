import SwiftUI

/// Detail view showing full information about a single file.
struct FileDetailView: View {
    let file: DuplicateFile
    let fileSize: UInt64

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // File name
            Label(file.displayName, systemImage: "doc")
                .font(.title2)

            Divider()

            // Metadata
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Path:")
                        .foregroundStyle(.secondary)
                    Text(file.path)
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("Size:")
                        .foregroundStyle(.secondary)
                    Text(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))
                }
                if let volume = file.volumeName {
                    GridRow {
                        Text("Volume:")
                            .foregroundStyle(.secondary)
                        Text(volume)
                    }
                }
                GridRow {
                    Text("Status:")
                        .foregroundStyle(.secondary)
                    Text(file.isKept ? "Keep" : "Delete")
                        .foregroundStyle(file.isKept ? .green : .red)
                }
            }

            Spacer()

            // Actions
            HStack {
                Button("Show in Finder") {
                    NSWorkspace.shared.selectFile(
                        file.path,
                        inFileViewerRootedAtPath: file.directoryPath
                    )
                }

                Button("Quick Look") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: file.path))
                }
            }
        }
        .padding()
        .frame(minWidth: 300)
    }
}
