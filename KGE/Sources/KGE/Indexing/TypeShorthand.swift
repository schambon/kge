import Foundation

/// Maps `[[type:id]]` type shorthands (e.g. `proj`) to their full canonical type value
/// (e.g. `project`). Any type used consistently works even without an explicit entry
/// here, since `expand` falls back to the input unchanged for unmapped shorthands.
enum TypeShorthand {
    private static let table: [String: String] = [
        "proj": "project"
    ]

    static func expand(_ shorthand: String) -> String {
        table[shorthand] ?? shorthand
    }

    /// Frontmatter `id` may be a bare id (`whatever`) or already the full slug
    /// (`task:whatever`). Returns the slug's bare id when its prefix names `type`
    /// (shorthands expanded), otherwise nil.
    static func bareID(_ id: String, type: String) -> String? {
        guard let colon = id.firstIndex(of: ":") else { return nil }
        let prefix = String(id[..<colon])
        guard expand(prefix) == expand(type) else { return nil }
        return String(id[id.index(after: colon)...])
    }

    /// Canonical `type:id` key for a node, tolerating an `id` that already carries the type prefix.
    static func canonicalKey(type: String, id: String) -> String {
        "\(expand(type)):\(bareID(id, type: type) ?? id)"
    }
}
