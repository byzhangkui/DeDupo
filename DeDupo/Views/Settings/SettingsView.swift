import SwiftUI

/// Application settings view.
struct SettingsView: View {
    @AppStorage("skipHiddenFiles") private var skipHiddenFiles = true
    @AppStorage("skipSystemDirs") private var skipSystemDirs = true
    @AppStorage("minFileSize") private var minFileSize = 0 // bytes, 0 = no minimum

    var body: some View {
        Form {
            Section("Scan Settings") {
                Toggle("Skip hidden files", isOn: $skipHiddenFiles)
                Toggle("Skip system directories", isOn: $skipSystemDirs)

                HStack {
                    Text("Minimum file size:")
                    TextField("0", value: $minFileSize, format: .number)
                        .frame(width: 80)
                    Text("bytes")
                        .foregroundStyle(.secondary)
                }
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")
                LabeledContent("Engine", value: "Rust Core + BLAKE3")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .frame(minWidth: 400)
    }
}
