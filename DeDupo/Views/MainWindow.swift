import SwiftUI

/// Main application window using NavigationSplitView.
struct MainWindow: View {
    @Environment(AppState.self) private var appState
    @State private var scannerViewModel = ScannerViewModel()
    @State private var resultsViewModel = ResultsViewModel()

    var body: some View {
        @Bindable var state = appState

        NavigationSplitView {
            List(selection: $state.selectedNavigation) {
                Section("Navigation") {
                    ForEach(NavigationItem.allCases) { item in
                        Label(item.rawValue, systemImage: item.systemImage)
                            .tag(item)
                    }
                }

                Section("Volumes") {
                    ForEach(appState.mountedVolumes) { volume in
                        Label(volume.name, systemImage: volume.isExternal ? "externaldrive" : "internaldrive")
                    }
                }
            }
            .navigationTitle("DeDupo")
        } detail: {
            switch appState.selectedNavigation {
            case .scanner:
                ScannerView(viewModel: scannerViewModel)
            case .results:
                ResultsView(viewModel: resultsViewModel)
            case .settings:
                SettingsView()
            }
        }
        .onAppear {
            resultsViewModel.loadSavedResults()
        }
        .onChange(of: scannerViewModel.scanCompleted) { _, completed in
            guard completed else { return }
            if scannerViewModel.isIncrementalScan {
                let newGroups = appState.engine?.getGroups() ?? []
                resultsViewModel.mergeResults(newGroups)
            } else {
                resultsViewModel.loadResults(engine: appState.engine)
            }
            resultsViewModel.saveResults()
            appState.selectedNavigation = .results
        }
    }
}
