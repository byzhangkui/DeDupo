import SwiftUI

/// Main application window using NavigationSplitView.
struct MainWindow: View {
    @Environment(AppState.self) private var appState

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
                ScannerView()
            case .results:
                ResultsView()
            case .settings:
                SettingsView()
            }
        }
    }
}
