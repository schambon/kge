import Foundation

/// Renders a dynamic view's filtered node list through the exact same
/// `HTMLTemplate`/`NodeListRenderer` path used for node pages (§3) — there is exactly
/// one HTML-generation path in the app, not a separate one for dynamic views.
enum DynamicViewRenderer {
    static func renderPage(name: String, typeCanonical: String, folderRelativePath: String, nodes: [DisplayNode]) -> String {
        let folderDescription = folderRelativePath.isEmpty ? "project root" : folderRelativePath
        let bodyHTML = "<p>All <code>\(typeCanonical.kgeHTMLEscaped)</code> nodes under <code>\(folderDescription.kgeHTMLEscaped)</code>.</p>"
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
