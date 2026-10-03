import SwiftUI

/// Quick-reference sheet listing every keyboard shortcut. Shown by `?` or Help ▸ Keyboard Shortcuts.
struct KeyboardHelpView: View {
    let onClose: () -> Void

    private struct Shortcut: Identifiable {
        let keys: String
        let action: String
        var id: String { keys }
    }

    private struct Section: Identifiable {
        let title: String
        let shortcuts: [Shortcut]
        var id: String { title }
    }

    private static let sections: [Section] = [
        Section(title: "Navigation", shortcuts: [
            Shortcut(keys: "j / k", action: "Next / previous link"),
            Shortcut(keys: "B", action: "Backlinks"),
            Shortcut(keys: "L", action: "Forward links"),
            Shortcut(keys: "S", action: "Switch focus between sidebar and content"),
            Shortcut(keys: "⌘← / <", action: "Back"),
            Shortcut(keys: "⌘→ / >", action: "Forward"),
        ]),
        Section(title: "Find & open", shortcuts: [
            Shortcut(keys: "⌘O", action: "Quick open"),
            Shortcut(keys: "⌘F or /", action: "Find (in the sidebar when it has focus)"),
            Shortcut(keys: "⇧⌘O", action: "Open folder"),
            Shortcut(keys: "⇧⌘F", action: "Reveal in Finder"),
        ]),
        Section(title: "Dynamic views", shortcuts: [
            Shortcut(keys: "D", action: "New dynamic view"),
            Shortcut(keys: "⌘S", action: "Save / delete dynamic view"),
        ]),
        Section(title: "Help", shortcuts: [
            Shortcut(keys: "?", action: "Show this help"),
        ]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Keyboard Shortcuts")
                .font(.headline)
            ForEach(Self.sections) { section in
                VStack(alignment: .leading, spacing: 6) {
                    Text(section.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(section.shortcuts) { shortcut in
                        HStack(alignment: .firstTextBaseline) {
                            Text(shortcut.keys)
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 110, alignment: .leading)
                            Text(shortcut.action)
                        }
                    }
                }
            }
            HStack {
                Spacer()
                Button("Close", action: onClose)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding()
        .frame(width: 420)
    }
}
