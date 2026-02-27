import SwiftUI

/// Main application entry point.
@main
struct DeDupoApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainWindow()
                .environment(appState)
        }
        .defaultSize(width: 900, height: 600)

        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}
