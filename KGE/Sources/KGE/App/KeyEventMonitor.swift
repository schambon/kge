import AppKit

/// Global handling for bare-letter/bare-symbol shortcuts (`s`, `d`, `/`, `<`, `>`) that
/// must work regardless of which pane has focus.
///
/// These are deliberately **not** given SwiftUI `.keyboardShortcut` menu equivalents:
/// `NSMenu.performKeyEquivalent` is consulted before the responder chain, so a bare-`d`
/// menu shortcut would steal keystrokes from any focused text field (quick-open's search
/// box, the dynamic-view builder's name field) before the field ever sees them. Instead
/// this installs one local event monitor and defers to a focused text field whenever one
/// is active — the standard "global unless a text field has focus" pattern.
///
/// `j`/`k`/`b`/`l` are handled separately, inside `KGEWebView.keyDown`, since they only
/// make sense when the web view itself is key.
@MainActor
final class KeyEventMonitor {
    private var monitor: Any?
    private var handlers: [String: () -> Void] = [:]

    /// Binds a bare key (no Command modifier) to an action. Re-registering the same key
    /// replaces its handler.
    func register(_ key: String, action: @escaping () -> Void) {
        handlers[key] = action
    }

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handle(event) ? nil : event
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    /// Returns `true` if the event was consumed.
    private func handle(_ event: NSEvent) -> Bool {
        guard !event.modifierFlags.contains(.command) else { return false }
        if isEditingTextField() { return false }

        guard let characters = event.charactersIgnoringModifiers,
              let action = handlers[characters] else { return false }

        action()
        return true
    }

    private func isEditingTextField() -> Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else { return false }
        if responder is NSTextView {
            // NSTextField's field editor is an NSTextView; this also covers plain
            // multi-line NSTextViews used as editable text.
            return true
        }
        return responder is NSTextField
    }
}
