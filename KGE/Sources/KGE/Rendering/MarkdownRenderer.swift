import Foundation
import Markdown

/// Renders a markdown file's contents to a full HTML page via the shared template.
///
/// Order of operations (see the build plan §3): split frontmatter, substitute wiki-links
/// against the current index snapshot, parse the substituted body as CommonMark/GFM,
/// format to HTML, post-process to add the resolved-link CSS class uniformly, then
/// assemble via the shared `HTMLTemplate`.
///
/// Forward-links/backlinks sections are layered in during M3 (currently always empty).
enum MarkdownRenderer {
    /// The file's raw text (frontmatter included) in a monospace block, through the
    /// same shared template — the "view source" counterpart of `renderPage`.
    static func renderSource(for file: MarkdownFile) -> String {
        let raw = (try? String(contentsOf: file.url, encoding: .utf8)) ?? "Could not read file."
        return HTMLTemplate.renderPage(
            title: file.displayLabel,
            slug: "source",
            bodyHTML: "<pre class=\"kge-source\">\(HTMLTemplate.escapeHTML(raw))</pre>",
            forwardLinksHTML: "",
            backlinksHTML: ""
        )
    }

    static func renderPage(for file: MarkdownFile, snapshot: IndexSnapshot) -> String {
        guard let raw = try? String(contentsOf: file.url, encoding: .utf8) else {
            return HTMLTemplate.renderPage(
                title: file.displayLabel,
                slug: "error",
                bodyHTML: "<p>Could not read file.</p>",
                forwardLinksHTML: "",
                backlinksHTML: ""
            )
        }

        let (yaml, body) = FrontmatterScanner.splitFrontmatter(raw)
        let substituted = WikiLinkResolver.resolve(body: body, snapshot: snapshot)

        let document = Document(parsing: substituted)
        var bodyHTML = HTMLFormatter.format(document)
        bodyHTML = rewriteRelativeFileLinks(in: bodyHTML, relativeTo: file.url)
        bodyHTML = addResolvedLinkClass(to: bodyHTML)

        let record = snapshot.records[file.url]
        let slug = record?.canonicalKey ?? file.url.lastPathComponent
        let forwardLinksHTML = record == nil ? "" : NodeListRenderer.renderSection(
            id: "kge-forwardlinks", title: "Forward links",
            nodes: NodeGraphQueries.forwardLinks(for: file.url, snapshot: snapshot)
        )
        let backlinksHTML = record?.canonicalKey == nil ? "" : NodeListRenderer.renderSection(
            id: "kge-backlinks", title: "Backlinks",
            nodes: NodeGraphQueries.backlinks(for: file.url, snapshot: snapshot)
        )

        return HTMLTemplate.renderPage(
            title: file.displayLabel,
            slug: slug,
            metadataHTML: MetadataRenderer.render(yaml: yaml),
            bodyHTML: bodyHTML,
            forwardLinksHTML: forwardLinksHTML,
            backlinksHTML: backlinksHTML
        )
    }

    /// Rewrites `<a href="rel/path.md">` links to existing local Markdown files into
    /// `kge://open` links, resolved relative to the directory of `fileURL`, so they
    /// navigate in-app (with history) like wiki-links. Links with a scheme, absolute
    /// paths, pure fragments, and targets that don't exist are left untouched.
    static func rewriteRelativeFileLinks(in html: String, relativeTo fileURL: URL) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"(<a\b[^>]*?\bhref=")([^"]*)(")"#) else {
            return html
        }
        let dir = fileURL.deletingLastPathComponent()
        let ns = html as NSString
        var result = html
        for m in regex.matches(in: html, range: NSRange(location: 0, length: ns.length)).reversed() {
            let raw = ns.substring(with: m.range(at: 2))
                .replacingOccurrences(of: "&amp;", with: "&")
            guard !raw.isEmpty, !raw.hasPrefix("#"), !raw.hasPrefix("/"), !raw.hasPrefix("?"),
                  raw.range(of: #"^[A-Za-z][A-Za-z0-9+.-]*:"#, options: .regularExpression) == nil
            else { continue }
            let pathPart = String(raw.prefix { $0 != "#" && $0 != "?" })
            guard let decoded = pathPart.removingPercentEncoding, !decoded.isEmpty else { continue }
            let target = URL(fileURLWithPath: decoded, relativeTo: dir).standardizedFileURL
            guard ["md", "markdown"].contains(target.pathExtension.lowercased()),
                  FileManager.default.fileExists(atPath: target.path) else { continue }
            let href = KGELink.openHref(for: target).kgeHTMLEscaped
            result = (result as NSString).replacingCharacters(in: m.range(at: 2), with: href)
        }
        return result
    }

    /// Post-process pass: inject `class="kge-link kge-resolved"` onto every
    /// `<a href="kge://open...">` tag that doesn't already carry a `class` attribute.
    /// This is the only place resolved-link styling is added — `WikiLinkResolver` never
    /// authors a class on single-match `<a>` tags, so there's exactly one code path
    /// adding it, applied uniformly to single-match links and to the anchors already
    /// present inside duplicate-match spans alike (harmless there too — both are
    /// correctly "resolved" links).
    private static func addResolvedLinkClass(to html: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"<a(?![^>]*\bclass=)([^>]*\bhref="kge://open[^"]*"[^>]*)>"#) else {
            return html
        }
        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        return regex.stringByReplacingMatches(
            in: html,
            range: nsRange,
            withTemplate: "<a class=\"kge-link kge-resolved\"$1>"
        )
    }
}
