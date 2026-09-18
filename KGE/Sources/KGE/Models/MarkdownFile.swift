import Foundation

/// A markdown file on disk, as a plain value the rendering pipeline operates on.
struct MarkdownFile {
    let url: URL

    /// The file's display label: filename minus the `.md` extension.
    var displayLabel: String {
        url.deletingPathExtension().lastPathComponent
    }
}
