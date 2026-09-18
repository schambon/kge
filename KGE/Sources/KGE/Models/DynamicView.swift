import Foundation

/// A saved filter: every node of canonical type `typeCanonical` under
/// `folderRelativePath` (subtree, not just direct children — `""` means the whole
/// project root). Persisted strictly locally, keyed to the project root; never synced.
struct DynamicView: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var typeCanonical: String
    var folderRelativePath: String

    init(id: UUID = UUID(), name: String, typeCanonical: String, folderRelativePath: String) {
        self.id = id
        self.name = name
        self.typeCanonical = typeCanonical
        self.folderRelativePath = folderRelativePath
    }

    /// Recomputes the filter fresh against `snapshot` — a saved view only ever persists
    /// the filter definition, never a materialized node list, so results stay live
    /// across index updates with no extra invalidation code.
    func matchingNodes(root: URL, snapshot: IndexSnapshot) -> [DisplayNode] {
        let folderURL = folderRelativePath.isEmpty ? root : root.appendingPathComponent(folderRelativePath)
        let folderPath = folderURL.standardizedFileURL.path

        let matchingKeys = snapshot.idIndex.keys.filter { key in
            key.split(separator: ":", maxSplits: 1).first.map(String.init) == typeCanonical
        }

        return matchingKeys
            .flatMap { snapshot.idIndex[$0] ?? [] }
            .filter { url in
                let path = url.standardizedFileURL.path
                return path == folderPath || path.hasPrefix(folderPath + "/")
            }
            .map { url in DisplayNode(url: url, label: IndexSnapshot.displayLabel(for: url), subtitle: typeCanonical) }
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }
}
