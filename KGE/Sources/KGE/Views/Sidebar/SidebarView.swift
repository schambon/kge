import SwiftUI

/// The real hierarchical sidebar: the project's file tree plus a virtual "Dynamic
/// Views" folder, in `.sidebar` style. Built from recursive `DisclosureGroup`s (rather
/// than `OutlineGroup`) so expansion state is owned by the caller and can be driven
/// programmatically — that's what powers auto-reveal of the current page.
struct SidebarView: View {
    let rootItems: [SidebarItem]
    @Binding var selection: URL?
    @Binding var expandedIDs: Set<String>
    var onSelectDynamicView: (DynamicView) -> Void = { _ in }

    var body: some View {
        ScrollViewReader { proxy in
            List(selection: $selection) {
                ForEach(rootItems) { item in
                    SidebarRow(item: item, expandedIDs: $expandedIDs, selection: $selection, onSelectDynamicView: onSelectDynamicView)
                }
            }
            .listStyle(.sidebar)
            .onChange(of: selection) { _, url in scrollToSelection(url, proxy: proxy) }
            .onChange(of: expandedIDs) { _, _ in scrollToSelection(selection, proxy: proxy) }
        }
    }

    /// Scrolls after the newly-expanded rows have been laid out.
    private func scrollToSelection(_ url: URL?, proxy: ScrollViewProxy) {
        guard let url else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            proxy.scrollTo(url, anchor: .center)
        }
    }
}

private struct SidebarRow: View {
    let item: SidebarItem
    @Binding var expandedIDs: Set<String>
    @Binding var selection: URL?
    let onSelectDynamicView: (DynamicView) -> Void

    var body: some View {
        if item.isDirectory {
            DisclosureGroup(isExpanded: expandedBinding) {
                // Children are only evaluated while expanded, keeping directory reads lazy.
                ForEach(item.children ?? []) { child in
                    SidebarRow(item: child, expandedIDs: $expandedIDs, selection: $selection, onSelectDynamicView: onSelectDynamicView)
                }
            } label: {
                Label(item.displayLabel, systemImage: "folder")
            }
        } else if let fileURL = item.fileURL {
            Label(item.displayLabel, systemImage: "doc.text")
                .tag(fileURL)
                .id(fileURL)
                .onTapGesture { selection = fileURL }
        } else if let dynamicView = item.dynamicViewValue {
            Label(item.displayLabel, systemImage: "line.3.horizontal.decrease.circle")
                .onTapGesture { onSelectDynamicView(dynamicView) }
        }
    }

    private var expandedBinding: Binding<Bool> {
        Binding(
            get: { expandedIDs.contains(item.id) },
            set: { isOn in
                if isOn { expandedIDs.insert(item.id) } else { expandedIDs.remove(item.id) }
            }
        )
    }
}
