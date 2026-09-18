import Foundation

/// The single shared HTML page shell used for every rendered surface in the app: node
/// pages, backlink/forward-link sections, and dynamic views alike. There is exactly one
/// HTML-generation path in the app — everything funnels through `renderPage`.
enum HTMLTemplate {
    static func renderPage(
        title: String,
        slug: String,
        bodyHTML: String,
        forwardLinksHTML: String,
        backlinksHTML: String
    ) -> String {
        let shell = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        \(css)
        </style>
        </head>
        <body>
        <header class="kge-header">
          <h1>{{TITLE}}</h1>
          <div class="kge-slug">{{SLUG}}</div>
        </header>
        <main class="kge-body">
        {{BODY}}
        </main>
        {{FORWARDLINKS}}
        {{BACKLINKS}}
        <script>
        \(script)
        </script>
        </body>
        </html>
        """

        return shell
            .replacingOccurrences(of: "{{TITLE}}", with: escapeHTML(title))
            .replacingOccurrences(of: "{{SLUG}}", with: escapeHTML(slug))
            .replacingOccurrences(of: "{{BODY}}", with: bodyHTML)
            .replacingOccurrences(of: "{{FORWARDLINKS}}", with: forwardLinksHTML)
            .replacingOccurrences(of: "{{BACKLINKS}}", with: backlinksHTML)
    }

    private static func escapeHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static let css = """
    :root {
        color-scheme: light dark;
        --fg: #1a1a1a;
        --bg: #ffffff;
        --muted: #666666;
        --border: #dddddd;
        --link: #0a66c2;
        --unresolved: #b23b3b;
        --code-bg: #f5f5f5;
        --focus: #0a66c2;
    }
    @media (prefers-color-scheme: dark) {
        :root {
            --fg: #e8e8e8;
            --bg: #1e1e1e;
            --muted: #999999;
            --border: #3a3a3a;
            --link: #6cb2ff;
            --unresolved: #ff8080;
            --code-bg: #2a2a2a;
            --focus: #6cb2ff;
        }
    }
    body {
        margin: 0;
        padding: 1.5rem 2rem 3rem;
        font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
        color: var(--fg);
        background: var(--bg);
        line-height: 1.55;
    }
    .kge-header { margin-bottom: 1.5rem; }
    .kge-header h1 { margin: 0 0 0.15rem; font-size: 1.6rem; }
    .kge-slug { color: var(--muted); font-family: ui-monospace, monospace; font-size: 0.85rem; }
    .kge-body { max-width: 46rem; }
    .kge-body pre { background: var(--code-bg); padding: 0.75rem 1rem; border-radius: 6px; overflow-x: auto; }
    .kge-body code { font-family: ui-monospace, monospace; }
    .kge-body table { border-collapse: collapse; margin: 1rem 0; }
    .kge-body th, .kge-body td { border: 1px solid var(--border); padding: 0.35rem 0.65rem; }
    .kge-body blockquote { border-left: 3px solid var(--border); margin: 1rem 0; padding-left: 1rem; color: var(--muted); }
    a.kge-link { text-decoration: none; }
    a.kge-resolved { color: var(--link); border-bottom: 1px solid var(--link); }
    .kge-unresolved { color: var(--unresolved); border-bottom: 1px dashed var(--unresolved); }
    a.kge-link.kge-focused { outline: 2px solid var(--focus); outline-offset: 2px; border-radius: 2px; }
    section.kge-node-section { max-width: 46rem; margin-top: 2rem; border-top: 1px solid var(--border); padding-top: 1rem; }
    section.kge-node-section h2 { font-size: 1rem; color: var(--muted); text-transform: uppercase; letter-spacing: 0.03em; }
    ul.kge-node-list { list-style: none; padding: 0; margin: 0; }
    ul.kge-node-list li { padding: 0.25rem 0; }
    ul.kge-node-list .kge-node-subtitle { color: var(--muted); font-family: ui-monospace, monospace; font-size: 0.8rem; margin-left: 0.5rem; }
    """

    private static let script = """
    function kgeLinks() { return Array.from(document.querySelectorAll('a.kge-link')); }
    var kgeFocusIndex = -1;
    function kgeApplyFocus() {
        kgeLinks().forEach(function(el, i) { el.classList.toggle('kge-focused', i === kgeFocusIndex); });
        var links = kgeLinks();
        if (kgeFocusIndex >= 0 && kgeFocusIndex < links.length) {
            links[kgeFocusIndex].scrollIntoView({ block: 'center', behavior: 'smooth' });
        }
    }
    function kgeFocusNextLink() {
        var links = kgeLinks();
        if (links.length === 0) { return; }
        kgeFocusIndex = (kgeFocusIndex + 1) % links.length;
        kgeApplyFocus();
    }
    function kgeFocusPrevLink() {
        var links = kgeLinks();
        if (links.length === 0) { return; }
        kgeFocusIndex = (kgeFocusIndex - 1 + links.length) % links.length;
        kgeApplyFocus();
    }
    function kgeActivateFocusedLink() {
        var links = kgeLinks();
        if (kgeFocusIndex >= 0 && kgeFocusIndex < links.length) {
            window.location.href = links[kgeFocusIndex].getAttribute('href');
        }
    }
    """
}
