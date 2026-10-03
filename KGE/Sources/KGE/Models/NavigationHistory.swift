import Foundation

/// A simple in-memory back/forward history stack over opened entries (nodes, dynamic views), in the style of
/// a browser's history. Not persisted — it's scoped to the current window session.
struct NavigationHistory<Entry: Equatable> {
    private var back: [Entry] = []
    private var forward: [Entry] = []
    private(set) var current: Entry?

    var canGoBack: Bool { !back.isEmpty }
    var canGoForward: Bool { !forward.isEmpty }

    /// Records navigation to a new node, clearing any forward history (the standard
    /// browser-history semantics: navigating away from a "back" state discards the
    /// abandoned forward branch).
    mutating func push(_ entry: Entry) {
        if let current, current != entry {
            back.append(current)
        }
        forward.removeAll()
        current = entry
    }

    /// Replaces the current entry without growing the stack (used for transient entries
    /// that are edited in place, e.g. the live dynamic-view builder).
    mutating func replaceCurrent(_ entry: Entry) {
        current = entry
    }

    mutating func goBack() -> Entry? {
        guard let previous = back.popLast() else { return nil }
        if let current {
            forward.append(current)
        }
        current = previous
        return previous
    }

    mutating func goForward() -> Entry? {
        guard let next = forward.popLast() else { return nil }
        if let current {
            back.append(current)
        }
        current = next
        return next
    }
}
