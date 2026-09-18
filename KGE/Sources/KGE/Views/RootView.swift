import SwiftUI

/// Top-level split view: sidebar (file tree / dynamic views) + content pane (rendered node).
///
/// This is a placeholder scaffold — see `KGE — Build Brief.md` at the repo root
/// for the intended architecture (WKWebView content pane, id index, backlinks,
/// dynamic views, keyboard-first navigation).
struct RootView: View {
    var body: some View {
        NavigationSplitView {
            Text("Sidebar")
                .frame(minWidth: 200)
        } detail: {
            Text("Open a folder to get started.")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    RootView()
}
