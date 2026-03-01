import SwiftUI

/// View displaying duplicate file groups found during a scan.
struct ResultsView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: ResultsViewModel
    @State private var showingDeleteConfirmation = false

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
        .alert(
            "Move \(viewModel.filesToDelete.count) files to the Trash?",
            isPresented: $showingDeleteConfirmation
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Move to Trash", role: .destructive) {
                deleteSelectedFiles()
            }
        } message: {
            Text("This will recover \(ByteCountFormatter.string(fromByteCount: Int64(viewModel.spaceToRecover), countStyle: .file)) of space.")
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
                showingDeleteConfirmation = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.filesToDelete.isEmpty)
        }
        .padding()
    }

    // MARK: - Actions

    private func deleteSelectedFiles() {
        let files = viewModel.filesToDelete
        let paths = files.map { $0.path }
        
        // Move to trash
        let successCount = TrashService.moveToTrash(paths: paths)
        
        if successCount > 0 {
            // Some or all files were deleted successfully
            // In a real scenario, we should only remove successfully trashed ones
            // But for MVP, we assume all paths attempted are returned on success
            // To be precise, we could check which paths exist, but let's just remove all requested paths from UI for now to be simple, 
            // or we could iterate and only add successful paths to the set.
            // Let's implement the robust way: only remove if it's no longer at the original path.
            var actuallyDeletedPaths = Set<String>()
            for path in paths {
                if !FileManager.default.fileExists(atPath: path) {
                    actuallyDeletedPaths.insert(path)
                }
            }
            viewModel.removeDeletedFiles(paths: actuallyDeletedPaths)
        }
    }
}
