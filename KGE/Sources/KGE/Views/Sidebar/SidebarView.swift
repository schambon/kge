import SwiftUI

/// The real hierarchical sidebar: the project's file tree plus a virtual "Dynamic
/// Views" folder, in `.sidebar` style via `OutlineGroup`.
struct SidebarView: View {
    let rootItems: [SidebarItem]
    @Binding var selection: URL?
    var onSelectDynamicView: (DynamicView) -> Void = { _ in }

    var body: some View {
        List {
            OutlineGroup(rootItems, children: \.children) { item in
                row(for: item)
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private func row(for item: SidebarItem) -> some View {
        if let fileURL = item.fileURL {
            Label(item.displayLabel, systemImage: "doc.text")
                .tag(fileURL)
                .onTapGesture { selection = fileURL }
        } else if let dynamicView = item.dynamicViewValue {
            Label(item.displayLabel, systemImage: "line.3.horizontal.decrease.circle")
                .onTapGesture { onSelectDynamicView(dynamicView) }
        } else {
            Label(item.displayLabel, systemImage: item.isDirectory ? "folder" : "questionmark")
        }
    }
}
