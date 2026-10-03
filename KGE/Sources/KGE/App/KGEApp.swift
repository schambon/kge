import SwiftUI

extension Notification.Name {
    /// Posted when the user asks to open a project folder, via the menu or toolbar.
    /// `RootView` owns the actual `NSOpenPanel` + `ProjectController` and listens for
    /// this so both entry points drive the same flow.
    static let kgeOpenFolderRequested = Notification.Name("kgeOpenFolderRequested")

    /// Posted by Cmd-F (and, in `RootView`'s `KeyEventMonitor`, bare `/`) to open the
    /// find-in-page bar.
    static let kgeFindRequested = Notification.Name("kgeFindRequested")

    /// Posted by Cmd-O to open the quick-open sheet.
    static let kgeQuickOpenRequested = Notification.Name("kgeQuickOpenRequested")

    /// Posted by Cmd-← / Cmd-→ (and bare `<` / `>`) for history navigation.
    static let kgeHistoryBackRequested = Notification.Name("kgeHistoryBackRequested")
    static let kgeHistoryForwardRequested = Notification.Name("kgeHistoryForwardRequested")

    /// Posted by `D` (bare key) to open the dynamic view builder.
    static let kgeDynamicViewRequested = Notification.Name("kgeDynamicViewRequested")

    /// Posted by Cmd-S: save the current transient dynamic view, or delete it if it's
    /// already saved (the title-bar icon toggles between the two states).
    static let kgeSaveOrDeleteDynamicViewRequested = Notification.Name("kgeSaveOrDeleteDynamicViewRequested")

    /// Posted by the "Reindex" menu item: a manual full reindex, for recovering from any
    /// changes missed while the app wasn't watching.
    static let kgeReindexRequested = Notification.Name("kgeReindexRequested")

    /// Posted by Cmd-Shift-F: reveal the current node (or open folder) in Finder.
    static let kgeRevealInFinderRequested = Notification.Name("kgeRevealInFinderRequested")

    /// Posted by `?` (bare key) and the Help menu item: show the keyboard shortcut reference.
    static let kgeKeyboardHelpRequested = Notification.Name("kgeKeyboardHelpRequested")
}

@main
struct KGEApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Folder…") {
                    NotificationCenter.default.post(name: .kgeOpenFolderRequested, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .help) {
                Button("Keyboard Shortcuts") {
                    NotificationCenter.default.post(name: .kgeKeyboardHelpRequested, object: nil)
                }
            }
            CommandGroup(after: .textEditing) {
                Button("Find…") {
                    NotificationCenter.default.post(name: .kgeFindRequested, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command])
            }
            CommandGroup(after: .toolbar) {
                Button("Quick Open…") {
                    NotificationCenter.default.post(name: .kgeQuickOpenRequested, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Back") {
                    NotificationCenter.default.post(name: .kgeHistoryBackRequested, object: nil)
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command])

                Button("Forward") {
                    NotificationCenter.default.post(name: .kgeHistoryForwardRequested, object: nil)
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command])

                Button("New Dynamic View…") {
                    NotificationCenter.default.post(name: .kgeDynamicViewRequested, object: nil)
                }

                Button("Save Dynamic View") {
                    NotificationCenter.default.post(name: .kgeSaveOrDeleteDynamicViewRequested, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command])

                Button("Reindex") {
                    NotificationCenter.default.post(name: .kgeReindexRequested, object: nil)
                }

                Button("Reveal in Finder") {
                    NotificationCenter.default.post(name: .kgeRevealInFinderRequested, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }
        }
    }
}
