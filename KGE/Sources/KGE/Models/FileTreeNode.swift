import Foundation

/// One row of the sidebar's filesystem tree. Deliberately **not** derived from
/// `GraphIndex` (which only knows flat URL -> record facts, no hierarchy) — built
/// directly from the filesystem, since the sidebar's structural walk and the graph's
/// id/backlink walk are different mechanisms.
///
/// Each node computes its own children only on first access, one directory level at a
/// time (a shallow `contentsOfDirectory` call, not a recursive enumerator), and caches
/// the result. This bounds the per-row cost regardless of how eagerly SwiftUI's
/// `List(_, children:)` outline machinery evaluates the `children` keypath (it may look
/// one level ahead of what's visible to decide whether to show a disclosure triangle) —
/// the cost of any single call stays a shallow directory listing, never a recursive walk
/// of the whole corpus.
final class FileTreeNode: Identifiable {
    /// Counts calls that actually hit the filesystem (as opposed to returning a cached
    /// result), so tests can assert the lazy/shallow-read guarantee directly. Not used
    /// by production code paths.
    nonisolated(unsafe) static var directoryReadCount = 0

    let url: URL
    let isDirectory: Bool
    var id: URL { url }

    /// `nil` = not yet computed; `.some(nil)` = computed and is a leaf (a file, or an
    /// unreadable/empty directory).
    private var _children: [FileTreeNode]??

    init(url: URL, isDirectory: Bool) {
        self.url = url
        self.isDirectory = isDirectory
    }

    var displayLabel: String {
        IndexSnapshot.displayLabel(for: url)
    }

    var children: [FileTreeNode]? {
        if let cached = _children {
            return cached
        }
        guard isDirectory else {
            _children = .some(nil)
            return nil
        }

        Self.directoryReadCount += 1
        let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        let kids = contents?
            .filter { item in
                let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                return isDir || item.pathExtension.lowercased() == "md"
            }
            .sorted(by: Self.directoriesFirstThenAlphabetical)
            .map { item -> FileTreeNode in
                let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                return FileTreeNode(url: item, isDirectory: isDir)
            }

        _children = .some(kids)
        return kids
    }

    /// Drops any cached children so the next access re-reads the filesystem. Used when
    /// FSEvents reports a directory-level change (M9).
    func invalidateChildren() {
        _children = nil
    }

    private static func directoriesFirstThenAlphabetical(_ a: URL, _ b: URL) -> Bool {
        let aIsDir = (try? a.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        let bIsDir = (try? b.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        if aIsDir != bIsDir { return aIsDir && !bIsDir }
        return a.lastPathComponent.localizedStandardCompare(b.lastPathComponent) == .orderedAscending
    }
}
