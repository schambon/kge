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
    private var swipeMonitor: Any?

    /// Called for a two-finger horizontal trackpad swipe: `back` when swiping right
    /// (Safari's convention), forward when swiping left.
    var onSwipeBack: (() -> Void)?
    var onSwipeForward: (() -> Void)?
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
        // WKWebView consumes horizontal two-finger gestures itself, so no `.swipe` NSEvent
        // ever reaches the app. Recognise the swipe from the scroll-wheel stream instead.
        swipeMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.trackSwipe(event)
            return event
        }
    }

    func stop() {
        if let swipeMonitor {
            NSEvent.removeMonitor(swipeMonitor)
        }
        swipeMonitor = nil
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    /// Horizontal distance (points of finger travel) past which releasing commits the swipe.
    private static let swipeCommitDistance: CGFloat = 220

    /// Reports the live horizontal drag (positive = fingers moved right) so the UI can slide
    /// the canvas; called with 0 when the gesture ends or is abandoned.
    var onSwipeProgress: ((CGFloat) -> Void)?

    private var swipeDX: CGFloat = 0
    private var swipeDY: CGFloat = 0
    private var swipeLocked = false

    /// Safari-style: a horizontal gesture first drags the canvas, and only navigates if it
    /// is carried far enough before the fingers lift. Never consumes the event.
    private func trackSwipe(_ event: NSEvent) {
        guard event.hasPreciseScrollingDeltas else { return }
        if event.momentumPhase != [] { return }
        if event.phase.contains(.began) || event.phase.contains(.mayBegin) {
            swipeDX = 0; swipeDY = 0; swipeLocked = false
        }
        if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            let dx = swipeDX
            let wasLocked = swipeLocked
            swipeDX = 0; swipeDY = 0; swipeLocked = false
            onSwipeProgress?(0)
            if wasLocked, abs(dx) > Self.swipeCommitDistance {
                if dx > 0 { onSwipeBack?() } else { onSwipeForward?() }
            }
            return
        }
        // Normalise so positive = fingers moved right, regardless of natural-scrolling setting.
        let sign: CGFloat = event.isDirectionInvertedFromDevice ? 1 : -1
        swipeDX += event.scrollingDeltaX * sign
        swipeDY += abs(event.scrollingDeltaY)
        if !swipeLocked, abs(swipeDX) > 24, abs(swipeDX) > 2 * swipeDY { swipeLocked = true }
        if swipeLocked { onSwipeProgress?(swipeDX) }
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
