import SwiftUI

/// View displaying duplicate file groups found during a scan.
struct ResultsView: View {
    @Environment(AppState.self) private var appState
    var viewModel: ResultsViewModel

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.groups.isEmpty {
                emptyState
            } else {
                resultsContent
            }
        }
        .navigationTitle("Results")
        .onAppear {
            if viewModel.groups.isEmpty {
                viewModel.loadResults(engine: appState.engine)
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        ContentUnavailableView(
            "No Results Yet",
            systemImage: "doc.on.doc",
            description: Text("Run a scan to find duplicate files.")
        )
    }

    // MARK: - Results Content

    @ViewBuilder
    private var resultsContent: some View {
        // Summary bar
        HStack {
            Text("Found \(viewModel.groups.count) duplicate groups")
                .font(.headline)
            Spacer()
            Text("Wasted space: \(viewModel.formattedTotalWasted)")
                .foregroundStyle(.secondary)
        }
        .padding()

        // Sort controls
        HStack {
            Picker("Sort by", selection: $viewModel.sortBy) {
                ForEach(SortOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)

            Button {
                viewModel.sortDescending.toggle()
            } label: {
                Image(systemName: viewModel.sortDescending ? "arrow.down" : "arrow.up")
            }

            Spacer()
        }
        .padding(.horizontal)

        // Group list
        List {
            ForEach(Array(viewModel.sortedGroups.enumerated()), id: \.element.id) { groupIdx, group in
                DuplicateGroupRow(
                    group: group,
                    onToggleKept: { fileIdx in
                        viewModel.toggleKept(groupIndex: groupIdx, fileIndex: fileIdx)
                    }
                )
            }
        }

        // Action bar
        HStack {
            Text("\(viewModel.filesToDelete.count) files selected for deletion")
                .foregroundStyle(.secondary)
            Spacer()
            Text("Space to recover: \(ByteCountFormatter.string(fromByteCount: Int64(viewModel.spaceToRecover), countStyle: .file))")
            Button("Delete Selected", role: .destructive) {
                // TrashService integration
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.filesToDelete.isEmpty)
        }
        .padding()
    }
}
