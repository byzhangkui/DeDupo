import SwiftUI

/// A row displaying a group of duplicate files.
struct DuplicateGroupRow: View {
    let group: DuplicateGroup
    let onToggleKept: (Int) -> Void

    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(Array(group.files.enumerated()), id: \.element.id) { index, file in
                HStack {
                    Toggle(isOn: Binding(
                        get: { file.isKept },
                        set: { _ in onToggleKept(index) }
                    )) {
                        EmptyView()
                    }
                    .toggleStyle(.checkbox)

                    Image(systemName: file.isKept ? "checkmark.circle.fill" : "trash.circle")
                        .foregroundStyle(file.isKept ? .green : .red)

                    VStack(alignment: .leading) {
                        Text(file.displayName)
                            .font(.body)
                        Text(file.directoryPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer()

                    if let volume = file.volumeName {
                        Text(volume)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary)
                            .clipShape(Capsule())
                    }
                }
                .padding(.vertical, 2)
            }
        } label: {
            HStack {
                Text("Group")
                    .font(.headline)
                Spacer()
                Text("\(group.files.count) files")
                    .foregroundStyle(.secondary)
                Text(group.formattedFileSize)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Wasted: \(group.formattedWastedSpace)")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.orange)
            }
        }
    }
}
