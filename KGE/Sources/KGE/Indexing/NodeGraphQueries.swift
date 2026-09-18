import Foundation

/// Resolves forward-links and backlinks for a node into `DisplayNode`s against an
/// `IndexSnapshot`. Shared by `MarkdownRenderer` (HTML sections) and the B/L keyboard
/// shortcut popovers (native SwiftUI lists) — the underlying graph query is never
/// duplicated between the two presentations.
enum NodeGraphQueries {
    /// `record.outgoingKeys` was already computed by the indexer — this resolves each
    /// key against `idIndex` (not a rescan of the body) into display nodes, with
    /// multiple rows per key when a target id is duplicated. Each target appears once, however
    /// many times the body links to it.
    static func forwardLinks(for url: URL, snapshot: IndexSnapshot) -> [DisplayNode] {
        guard let record = snapshot.records[url] else { return [] }
        var seen = Set<URL>()
        return record.outgoingKeys.flatMap { key -> [DisplayNode] in
            (snapshot.idIndex[key] ?? []).compactMap { target in
                guard seen.insert(target).inserted else { return nil }
                return DisplayNode(url: target, label: IndexSnapshot.displayLabel(for: target), subtitle: key)
            }
        }
    }

    /// A file with no `canonicalKey` can't be a link target, so it has no backlinks by
    /// construction.
    static func backlinks(for url: URL, snapshot: IndexSnapshot) -> [DisplayNode] {
        guard let canonicalKey = snapshot.records[url]?.canonicalKey else { return [] }
        let sources = snapshot.backlinkIndex[canonicalKey] ?? []
        return sources.map { source -> DisplayNode in
            let subtitle = snapshot.records[source]?.canonicalKey
            return DisplayNode(url: source, label: IndexSnapshot.displayLabel(for: source), subtitle: subtitle)
        }.sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }
}
