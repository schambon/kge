import SwiftUI

@main
struct KGEApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Folder…") {
                    // TODO: wire up project-root open flow (Indexing).
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
        }
    }
}
