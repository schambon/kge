import Foundation
import Yams

/// Renders a node's complete frontmatter as an HTML key/value block for the page header.
/// Scalars are shown inline, lists as bullet lists, nested maps as nested key/value
/// blocks. Key order follows the file. Everything is HTML-escaped.
enum MetadataRenderer {
    static func render(yaml: String?) -> String {
        guard let yaml, let node = try? Yams.compose(yaml: yaml),
              let mapping = node.mapping, !mapping.isEmpty else { return "" }
        return "<dl class=\"kge-meta\">\(entries(mapping))</dl>"
    }

    private static func entries(_ mapping: Node.Mapping) -> String {
        mapping.map { key, value in
            "<dt>\(HTMLTemplate.escapeHTML(key.scalar?.string ?? ""))</dt><dd>\(valueHTML(value))</dd>"
        }.joined()
    }

    private static func valueHTML(_ node: Node) -> String {
        switch node {
        case .scalar(let s):
            return HTMLTemplate.escapeHTML(s.string)
        case .sequence(let seq):
            if seq.isEmpty { return "" }
            return "<ul>" + seq.map { "<li>\(valueHTML($0))</li>" }.joined() + "</ul>"
        case .mapping(let map):
            return "<dl class=\"kge-meta\">\(entries(map))</dl>"
        case .alias(let a):
            return HTMLTemplate.escapeHTML(a.anchor.rawValue)
        }
    }
}
