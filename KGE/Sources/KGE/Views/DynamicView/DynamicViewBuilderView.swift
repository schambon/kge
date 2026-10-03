import SwiftUI

/// The `D` shortcut's sheet: pick a folder (subtree) and build a query as a table of
/// `attribute : value` rows, all of which must match. `type` is just the reserved
/// attribute for the node type. Renders immediately as anything changes — there's no
/// separate "apply" step; the caller re-renders on every change to the bindings.
struct DynamicViewBuilderView: View {
    /// Non-nil when editing a saved view: shows a name field and a Cancel button.
    var name: Binding<String>? = nil
    var onCancel: (() -> Void)? = nil

    let availableTypes: [String]
    let availableFolders: [String] // relative paths, "" = project root

    @Binding var criteria: [ViewCriterion]
    @Binding var folderRelativePath: String
    @Binding var labelStyle: LinkLabelStyle

    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(name == nil ? "Dynamic View" : "Edit Dynamic View")
                .font(.headline)

            if let name {
                TextField("Name", text: name)
                    .textFieldStyle(.roundedBorder)
            }

            Picker("Folder", selection: $folderRelativePath) {
                Text("Project root").tag("")
                ForEach(availableFolders.filter { !$0.isEmpty }, id: \.self) { folder in
                    Text(folder).tag(folder)
                }
            }

            Picker("Display as", selection: $labelStyle) {
                ForEach(LinkLabelStyle.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                GridRow {
                    Text("Attribute").font(.caption).foregroundStyle(.secondary)
                    Text("Value").font(.caption).foregroundStyle(.secondary)
                    Color.clear.frame(width: 20, height: 1)
                }
                ForEach($criteria) { $criterion in
                    GridRow {
                        TextField("attribute", text: $criterion.key)
                            .textFieldStyle(.roundedBorder)
                        HStack(spacing: 4) {
                            TextField("value", text: $criterion.value)
                                .textFieldStyle(.roundedBorder)
                            if criterion.key.lowercased() == "type" {
                                Menu {
                                    ForEach(availableTypes, id: \.self) { type in
                                        Button(type) { criterion.value = type }
                                    }
                                } label: { Image(systemName: "chevron.down") }
                                .menuStyle(.borderlessButton)
                                .frame(width: 20)
                            }
                        }
                        Button {
                            criteria.removeAll { $0.id == criterion.id }
                        } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.borderless)
                    }
                }
            }

            Button {
                criteria.append(ViewCriterion(key: "", value: ""))
            } label: { Label("Add Criterion", systemImage: "plus") }

            HStack {
                Spacer()
                if let onCancel {
                    Button("Cancel", action: onCancel)
                }
                Button("Done", action: onClose)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 440)
    }
}
