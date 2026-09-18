import Foundation

/// Small HTML-generation helpers shared across the rendering pipeline, so escaping and
/// the `kge://open` href format are never duplicated/allowed to drift between
/// `WikiLinkResolver` and `NodeListRenderer`.
enum KGELink {
    static func openHref(for url: URL) -> String {
        var components = URLComponents()
        components.scheme = "kge"
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "path", value: url.path)]
        return components.url?.absoluteString ?? ""
    }
}

extension String {
    var kgeHTMLEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    var kgeHTMLAttrEscaped: String {
        kgeHTMLEscaped.replacingOccurrences(of: "\"", with: "&quot;")
    }
}
