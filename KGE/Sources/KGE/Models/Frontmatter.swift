import Foundation

/// A node's frontmatter fields relevant to the knowledge graph. Decoded via
/// `YAMLDecoder().decode(Frontmatter.self, from:)`. Missing or malformed fields decode
/// to `nil` rather than throwing where possible; a fully malformed YAML block is caught
/// upstream and treated as "no frontmatter" — the file is still indexed as a plain,
/// id-less file, never crashes the indexer.
struct Frontmatter: Decodable, Sendable {
    let id: String?
    let type: String?
}
