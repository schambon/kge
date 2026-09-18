import Foundation

/// One `attribute:value` test. The reserved key `type` matches the node's canonical type
/// (shorthands expanded); any other key matches a frontmatter attribute, case-insensitively,
/// against the scalar value or any element of a list value.
struct ViewCriterion: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var key: String
    var value: String

    private enum CodingKeys: String, CodingKey { case key, value }

    init(key: String, value: String) {
        self.key = key
        self.value = value
    }

    var isComplete: Bool {
        !key.trimmingCharacters(in: .whitespaces).isEmpty && !value.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func matches(_ record: IndexSnapshot.FileRecord) -> Bool {
        let key = key.trimmingCharacters(in: .whitespaces)
        let value = value.trimmingCharacters(in: .whitespaces)
        if key.lowercased() == "type" {
            guard let type = record.frontmatter?.type else { return false }
            return TypeShorthand.expand(type) == TypeShorthand.expand(value)
        }
        guard let actual = record.attributes.first(where: { $0.key.caseInsensitiveCompare(key) == .orderedSame })?.value else {
            return false
        }
        return actual.contains { $0.caseInsensitiveCompare(value) == .orderedSame }
    }
}

/// A saved filter: every node under `folderRelativePath` (subtree, not just direct
/// children — `""` means the whole project root) satisfying all `criteria`. Persisted
/// strictly locally, keyed to the project root; never synced.
struct DynamicView: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var folderRelativePath: String
    var criteria: [ViewCriterion]

    init(id: UUID = UUID(), name: String, folderRelativePath: String, criteria: [ViewCriterion]) {
        self.id = id
        self.name = name
        self.folderRelativePath = folderRelativePath
        self.criteria = criteria
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, folderRelativePath, criteria, typeCanonical
    }

    // Views saved before the query builder stored a single `typeCanonical`; fold it into a `type` criterion.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        folderRelativePath = try c.decode(String.self, forKey: .folderRelativePath)
        if let criteria = try c.decodeIfPresent([ViewCriterion].self, forKey: .criteria) {
            self.criteria = criteria
        } else if let legacy = try c.decodeIfPresent(String.self, forKey: .typeCanonical) {
            criteria = [ViewCriterion(key: "type", value: legacy)]
        } else {
            criteria = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(folderRelativePath, forKey: .folderRelativePath)
        try c.encode(criteria, forKey: .criteria)
    }

    /// Recomputes the filter fresh against `snapshot` — a saved view only ever persists
    /// the filter definition, never a materialized node list, so results stay live
    /// across index updates with no extra invalidation code.
    func matchingNodes(root: URL, snapshot: IndexSnapshot) -> [DisplayNode] {
        let folderURL = folderRelativePath.isEmpty ? root : root.appendingPathComponent(folderRelativePath)
        let folderPath = folderURL.standardizedFileURL.path
        let active = criteria.filter(\.isComplete)

        return snapshot.records
            .filter { url, record in
                guard record.canonicalKey != nil else { return false }
                let path = url.standardizedFileURL.path
                guard path == folderPath || path.hasPrefix(folderPath + "/") else { return false }
                return active.allSatisfy { $0.matches(record) }
            }
            .map { url, record in
                let type = record.frontmatter?.type.map(TypeShorthand.expand) ?? ""
                return DisplayNode(url: url, label: IndexSnapshot.displayLabel(for: url), subtitle: type)
            }
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }
}
