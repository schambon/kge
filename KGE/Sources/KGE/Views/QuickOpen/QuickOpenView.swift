import SwiftUI

/// One row of the quick-open list: either a node or a saved dynamic view.
enum QuickOpenItem: Identifiable {
    case node(DisplayNode)
    case dynamicView(DynamicView)

    var id: String {
        switch self {
        case .node(let node): "node:\(node.url.path)"
        case .dynamicView(let view): "dynamicView:\(view.id)"
        }
    }

    var label: String {
        switch self {
        case .node(let node): node.label
        case .dynamicView(let view): view.name
        }
    }

    var subtitle: String? {
        switch self {
        case .node(let node): node.subtitle
        case .dynamicView: "Dynamic View"
        }
    }
}

/// Cmd-O quick-open: a typeahead-filtered list of every indexed node plus every saved
/// dynamic view.
struct QuickOpenView: View {
    let snapshot: IndexSnapshot
    let dynamicViews: [DynamicView]
    let onSelect: (URL) -> Void
    let onSelectDynamicView: (DynamicView) -> Void
    let onCancel: () -> Void

    @State private var query = ""
    @FocusState private var isFocused: Bool

    private var allItems: [QuickOpenItem] {
        // (a) every URL with a canonicalKey, subtitle = type:id, duplicates as separate rows.
        let withIds = snapshot.idIndex.flatMap { key, urls in
            urls.map { url in DisplayNode(url: url, label: IndexSnapshot.displayLabel(for: url), subtitle: key) }
        }
        let idURLs = Set(withIds.map(\.url))
        // (b) all other plain .md files, label only.
        let withoutIds = snapshot.records.keys
            .filter { !idURLs.contains($0) }
            .map { DisplayNode(url: $0, label: IndexSnapshot.displayLabel(for: $0), subtitle: nil) }
        let nodeItems = (withIds + withoutIds)
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
            .map(QuickOpenItem.node)
        // (c) all dynamic views.
        let viewItems = dynamicViews
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .map(QuickOpenItem.dynamicView)
        return viewItems + nodeItems
    }

    private var filteredItems: [QuickOpenItem] {
        guard !query.isEmpty else { return allItems }
        return allItems.filter { $0.label.localizedCaseInsensitiveContains(query) || ($0.subtitle?.localizedCaseInsensitiveContains(query) ?? false) }
    }

    private func select(_ item: QuickOpenItem) {
        switch item {
        case .node(let node): onSelect(node.url)
        case .dynamicView(let view): onSelectDynamicView(view)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Quick Open", text: $query)
                .textFieldStyle(.plain)
                .font(.title3)
                .padding()
                .focused($isFocused)
                .onSubmit {
                    if let first = filteredItems.first {
                        select(first)
                    }
                }

            Divider()

            List(filteredItems) { item in
                Button {
                    select(item)
                } label: {
                    VStack(alignment: .leading) {
                        Text(item.label)
                        if let subtitle = item.subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 420, height: 360)
        .onAppear { isFocused = true }
        .onExitCommand(perform: onCancel)
    }
}
