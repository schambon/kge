import SwiftUI

/// The native SwiftUI list shown by the `B` (backlinks) / `L` (forward-links) keyboard
/// shortcuts — deliberately a plain `List`, not a second WebView, since this is a quick
/// glance/jump panel rather than rendered prose.
struct LinksPopoverView: View {
    let title: String
    let nodes: [DisplayNode]
    let onSelect: (URL) -> Void

    @State private var selectedURL: URL?
    @FocusState private var isFocused: Bool

    private func moveSelection(_ delta: Int) {
        guard !nodes.isEmpty else { return }
        let current = nodes.firstIndex { $0.url == selectedURL } ?? (delta > 0 ? -1 : nodes.count)
        selectedURL = nodes[min(max(current + delta, 0), nodes.count - 1)].url
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.headline)
                .padding([.horizontal, .top])
                .padding(.bottom, 4)
            if nodes.isEmpty {
                Text("None.")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ScrollViewReader { proxy in
                List(nodes, id: \.url) { node in
                    Button {
                        onSelect(node.url)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(node.label)
                            if let subtitle = node.subtitle {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(node.url == selectedURL ? Color.accentColor.opacity(0.25) : Color.clear)
                    .id(node.url)
                }
                .focusable()
                .focused($isFocused)
                .onKeyPress(.downArrow) { moveSelection(1); return .handled }
                .onKeyPress(.upArrow) { moveSelection(-1); return .handled }
                .onKeyPress("j") { moveSelection(1); return .handled }
                .onKeyPress("k") { moveSelection(-1); return .handled }
                .onKeyPress(.return) {
                    if let url = selectedURL { onSelect(url) }
                    return .handled
                }
                .onChange(of: selectedURL) { if let url = selectedURL { proxy.scrollTo(url) } }
                }
            }
        }
        .frame(minWidth: 260, minHeight: 200)
        .onAppear {
            selectedURL = nodes.first?.url
            isFocused = true
        }
    }
}
