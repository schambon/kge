import Foundation

/// A simple in-memory back/forward history stack over opened node URLs, in the style of
/// a browser's history. Not persisted — it's scoped to the current window session.
struct NavigationHistory {
    private var back: [URL] = []
    private var forward: [URL] = []
    private(set) var current: URL?

    var canGoBack: Bool { !back.isEmpty }
    var canGoForward: Bool { !forward.isEmpty }

    /// Records navigation to a new node, clearing any forward history (the standard
    /// browser-history semantics: navigating away from a "back" state discards the
    /// abandoned forward branch).
    mutating func push(_ url: URL) {
        if let current, current != url {
            back.append(current)
        }
        forward.removeAll()
        current = url
    }

    mutating func goBack() -> URL? {
        guard let previous = back.popLast() else { return nil }
        if let current {
            forward.append(current)
        }
        current = previous
        return previous
    }

    mutating func goForward() -> URL? {
        guard let next = forward.popLast() else { return nil }
        if let current {
            back.append(current)
        }
        current = next
        return next
    }
}
