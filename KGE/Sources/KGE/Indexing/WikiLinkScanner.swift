import Foundation

/// One `[[type:id]]` or `[[type:id|label]]` occurrence found in a file's body text.
struct WikiLinkOccurrence {
    let range: Range<String.Index>
    let typeShorthand: String
    let id: String
    let label: String?
}

/// Locates `[[type:id]]` / `[[type:id|label]]` wiki-link syntax in raw body text.
///
/// This is the **single source of truth** for locating this syntax — both the indexer's
/// outgoing-link pass (`GraphIndex.reindex`) and the renderer's substitution pass
/// (`WikiLinkResolver`) call this same function, so the pattern is never duplicated or
/// allowed to drift.
enum WikiLinkScanner {
    private static let regex: NSRegularExpression = {
        // [[type:id]] or [[type:id|label]]
        try! NSRegularExpression(pattern: #"\[\[([A-Za-z0-9_-]+):([^\]|]+)(?:\|([^\]]+))?\]\]"#)
    }()

    static func scanWikiLinks(in body: String) -> [WikiLinkOccurrence] {
        let nsRange = NSRange(body.startIndex..<body.endIndex, in: body)
        let matches = regex.matches(in: body, range: nsRange)

        return matches.compactMap { match -> WikiLinkOccurrence? in
            guard
                let fullRange = Range(match.range, in: body),
                let typeRange = Range(match.range(at: 1), in: body),
                let idRange = Range(match.range(at: 2), in: body)
            else { return nil }

            let labelRange = match.range(at: 3)
            let label: String? = labelRange.location != NSNotFound ? Range(labelRange, in: body).map { String(body[$0]) } : nil

            return WikiLinkOccurrence(
                range: fullRange,
                typeShorthand: String(body[typeRange]),
                id: String(body[idRange]),
                label: label
            )
        }
    }
}
