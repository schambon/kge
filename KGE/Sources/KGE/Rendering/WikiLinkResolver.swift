import Foundation

/// Resolves `[[type:id]]` wiki-links in raw body text against an `IndexSnapshot`,
/// substituting each occurrence before CommonMark parsing. `[[type:id]]` is not
/// CommonMark syntax, so cmark-gfm cannot parse it directly — this pre-pass turns each
/// occurrence into either a normal Markdown link (single resolved match), raw HTML with
/// multiple anchors (duplicate ids), or a styled unresolved span, before the text is
/// handed to `Document(parsing:)`.
enum WikiLinkResolver {
    /// Substitutes every wiki-link occurrence in `body` against `snapshot`. Path
    /// resolution happens now, at render time, against the given snapshot — there is no
    /// click-time re-resolution and no HTML caching across renders, so every navigation
    /// regenerates fresh from whatever snapshot is current.
    static func resolve(body: String, snapshot: IndexSnapshot) -> String {
        let occurrences = WikiLinkScanner.scanWikiLinks(in: body)
        guard !occurrences.isEmpty else { return body }

        var result = body
        // Work through occurrences in reverse range order so earlier replacements
        // don't invalidate later ranges.
        for occurrence in occurrences.sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) {
            let canonicalKey = "\(TypeShorthand.expand(occurrence.typeShorthand)):\(occurrence.id)"
            let matches = snapshot.idIndex[canonicalKey] ?? []
            let replacement = replacementText(occurrence: occurrence, canonicalKey: canonicalKey, matches: matches)
            result.replaceSubrange(occurrence.range, with: replacement)
        }
        return result
    }

    private static func replacementText(
        occurrence: WikiLinkOccurrence,
        canonicalKey: String,
        matches: [URL]
    ) -> String {
        switch matches.count {
        case 0:
            return "<span class=\"kge-link kge-unresolved\" data-kge-key=\"\(canonicalKey.kgeHTMLAttrEscaped)\">\(occurrence.typeShorthand.kgeHTMLEscaped):\(occurrence.id.kgeHTMLEscaped)</span>"

        case 1:
            let target = matches[0]
            let label = occurrence.label ?? IndexSnapshot.displayLabel(for: target)
            let href = KGELink.openHref(for: target)
            return "[\(escapeMarkdownLinkText(label))](\(href))"

        default:
            // Duplicate ids: multiple independent anchors in one occurrence, authored
            // as raw HTML since `[[ ]]` markdown syntax can't express this. The `|label`
            // override, if present, is ignored here (ambiguous which target it labels)
            // — display always falls back to each target's own filename.
            let anchors = matches.map { target -> String in
                let href = KGELink.openHref(for: target)
                let label = IndexSnapshot.displayLabel(for: target)
                return "<a class=\"kge-link kge-resolved\" href=\"\(href)\">\(label.kgeHTMLEscaped)</a>"
            }
            return anchors.joined(separator: " | ")
        }
    }

    private static func escapeMarkdownLinkText(_ s: String) -> String {
        s.replacingOccurrences(of: "[", with: "\\[").replacingOccurrences(of: "]", with: "\\]")
    }
}
