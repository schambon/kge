import SwiftUI

/// The `D` shortcut's sheet: pick a type (typeahead) and a folder (subtree, defaulting
/// to the currently-open node's containing folder, or the project root). Per the brief,
/// it renders immediately as selections change — there's no separate "apply" step; the
/// caller re-renders on every change to `typeCanonical`/`folderRelativePath`.
struct DynamicViewBuilderView: View {
    let availableTypes: [String]
    let availableFolders: [String] // relative paths, "" = project root

    @Binding var typeCanonical: String
    @Binding var folderRelativePath: String

    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dynamic View")
                .font(.headline)

            Picker("Type", selection: $typeCanonical) {
                ForEach(availableTypes, id: \.self) { type in
                    Text(type).tag(type)
                }
            }

            Picker("Folder", selection: $folderRelativePath) {
                Text("Project root").tag("")
                ForEach(availableFolders.filter { !$0.isEmpty }, id: \.self) { folder in
                    Text(folder).tag(folder)
                }
            }

            HStack {
                Spacer()
                Button("Done", action: onClose)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 320)
    }
}
