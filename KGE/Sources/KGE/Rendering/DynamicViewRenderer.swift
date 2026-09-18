import Foundation

/// Renders a dynamic view's filtered node list through the exact same
/// `HTMLTemplate`/`NodeListRenderer` path used for node pages (§3) — there is exactly
/// one HTML-generation path in the app, not a separate one for dynamic views.
enum DynamicViewRenderer {
    static func renderPage(name: String, criteria: [ViewCriterion], folderRelativePath: String, nodes: [DisplayNode]) -> String {
        let folderDescription = folderRelativePath.isEmpty ? "project root" : folderRelativePath
        let active = criteria.filter(\.isComplete)
        let criteriaText = active.isEmpty ? "all nodes" : active.map { "\($0.key):\($0.value)" }.joined(separator: ", ")
        let bodyHTML = "<p><code>\(criteriaText.kgeHTMLEscaped)</code> under <code>\(folderDescription.kgeHTMLEscaped)</code>.</p>"
            + NodeListRenderer.renderNodeListHTML(nodes)

        return HTMLTemplate.renderPage(
            title: name,
            slug: "dynamic view",
            bodyHTML: bodyHTML,
            forwardLinksHTML: "",
            backlinksHTML: ""
        )
    }
}
