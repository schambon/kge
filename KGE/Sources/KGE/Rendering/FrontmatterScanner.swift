import Foundation

/// Locates and strips a leading YAML frontmatter fence (`---` ... `---`) from raw
/// markdown file text. This is the single place frontmatter is ever located — both
/// the indexer and the renderer call this same function; never re-implement the scan
/// elsewhere.
enum FrontmatterScanner {
    /// Splits `raw` into an optional YAML block and the remaining body.
    ///
    /// If the text begins with a line that is exactly `---`, scans forward for the next
    /// line that is exactly `---`. If found, `yaml` is the text between the fences and
    /// `body` is everything after the second fence (leading newline trimmed). If there is
    /// no opening fence at the very start of the text, `yaml` is `nil` and `body` is the
    /// input unchanged.
    static func splitFrontmatter(_ raw: String) -> (yaml: String?, body: String) {
        var lines = raw.split(separator: "\n", omittingEmptySubsequences: false)[...]

        guard let first = lines.first, first.trimmingCharacters(in: .whitespaces) == "---" else {
            return (nil, raw)
        }
        lines.removeFirst()

        var yamlLines: [Substring] = []
        var foundClosingFence = false
        while let line = lines.first {
            lines.removeFirst()
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                foundClosingFence = true
                break
            }
            yamlLines.append(line)
        }

        guard foundClosingFence else {
            // No closing fence: treat the whole thing as body, no frontmatter.
            return (nil, raw)
        }

        let yaml = yamlLines.joined(separator: "\n")
        let body = lines.joined(separator: "\n")
        return (yaml, body)
    }
}
