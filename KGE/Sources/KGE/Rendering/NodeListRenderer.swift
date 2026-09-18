import Foundation

/// A resolved node ready for display in a list: forward-links, backlinks, quick-open
/// results, and dynamic-view results all render through this same shape.
struct DisplayNode {
    let url: URL
    let label: String
    let subtitle: String?
}

/// Renders a list of `DisplayNode`s as the single shared `<ul class="kge-node-list">`
/// markup, reused by forward-links, backlinks, and dynamic views alike — there is
/// exactly one node-list rendering path in the app.
enum NodeListRenderer {
    static func renderNodeListHTML(_ nodes: [DisplayNode]) -> String {
        guard !nodes.isEmpty else {
            return "<p class=\"kge-empty\">None.</p>"
        }
        let items = nodes.map { node -> String in
            let href = KGELink.openHref(for: node.url)
            let subtitle = node.subtitle.map { " <span class=\"kge-node-subtitle\">\($0.kgeHTMLEscaped)</span>" } ?? ""
            return "<li><a class=\"kge-link kge-resolved\" href=\"\(href)\">\(node.label.kgeHTMLEscaped)</a>\(subtitle)</li>"
        }
        return "<ul class=\"kge-node-list\">\(items.joined())</ul>"
    }

    static func renderSection(id: String, title: String, nodes: [DisplayNode]) -> String {
        "<section class=\"kge-node-section\" id=\"\(id)\"><h2>\(title.kgeHTMLEscaped)</h2>\(renderNodeListHTML(nodes))</section>"
    }
}
