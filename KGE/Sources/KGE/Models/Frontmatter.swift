import Foundation
import Yams

/// A node's frontmatter fields relevant to the knowledge graph. Decoded via
/// `YAMLDecoder().decode(Frontmatter.self, from:)`. Missing or malformed fields decode
/// to `nil` rather than throwing where possible; a fully malformed YAML block is caught
/// upstream and treated as "no frontmatter" — the file is still indexed as a plain,
/// id-less file, never crashes the indexer.
struct Frontmatter: Decodable, Sendable {
    let id: String?
    let type: String?
}

extension Frontmatter {
    /// Every top-level scalar or list attribute as strings; nested maps are ignored.
    static func attributes(fromYAML yaml: String) -> [String: [String]] {
        guard let dict = (try? Yams.load(yaml: yaml)) as? [String: Any] else { return [:] }
        func scalar(_ value: Any) -> String? {
            switch value {
            case let s as String: return s
            case is [Any], is [String: Any], is NSNull: return nil
            default: return String(describing: value)
            }
        }
        var result: [String: [String]] = [:]
        for (key, value) in dict {
            if let list = value as? [Any] {
                result[key] = list.compactMap(scalar)
            } else if let s = scalar(value) {
                result[key] = [s]
            }
        }
        return result
    }
}
