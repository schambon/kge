import Foundation

/// Owns the currently-open project root, drives (re)indexing, and publishes the
/// resulting `IndexSnapshot` for the UI to render against.
@MainActor
final class ProjectController: ObservableObject {
    @Published private(set) var projectRoot: URL?
    @Published private(set) var rootFileTreeNode: FileTreeNode?
    @Published private(set) var snapshot = IndexSnapshot()
    @Published private(set) var isIndexing = false

    /// Bumped whenever a directory-level FSEvents change is reported; `RootView` rebuilds
    /// the sidebar's root `FileTreeNode` when this changes, dropping stale per-node
    /// child caches without re-walking anything eagerly (children are lazy/cached per
    /// `FileTreeNode`).
    @Published private(set) var treeGeneration = 0

    let graphIndex = GraphIndex()
    private var fileWatcher: FileWatcher?

    /// Set only when the current root's access was granted via a resolved
    /// security-scoped bookmark (i.e. restored on relaunch, not freshly chosen via
    /// `NSOpenPanel`) — that's the only case requiring a matching
    /// `stopAccessingSecurityScopedResource()` when the project changes.
    private var securityScopedRoot: URL?

    /// Opens `root` as the project: walks the folder, indexes every `.md` file via the
    /// shared `reindex` primitive, publishes a snapshot when done, then starts the
    /// FSEvents watcher. Persists a security-scoped bookmark so a relaunch can restore
    /// this root without re-prompting.
    func openProject(at root: URL) async {
        fileWatcher?.stop()
        fileWatcher = nil

        if let securityScopedRoot, securityScopedRoot != root {
            securityScopedRoot.stopAccessingSecurityScopedResource()
            self.securityScopedRoot = nil
        }
        ProjectBookmarkStore.save(root)

        projectRoot = root
        rootFileTreeNode = FileTreeNode(url: root, isDirectory: true)
        isIndexing = true

        for url in Self.discoverMarkdownFiles(under: root) {
            await graphIndex.reindex(url: url, action: .addOrUpdate)
        }
        snapshot = await graphIndex.snapshot()
        isIndexing = false

        startWatching(root: root)
    }

    /// Restores the last-opened project on launch, if a bookmark was saved.
    /// `ProjectBookmarkStore.restoreLastProject()` already starts accessing the
    /// security-scoped resource; this tracks it so it's matched by a `stop` call later.
    func restoreLastProjectIfAvailable() async {
        guard let root = ProjectBookmarkStore.restoreLastProject() else { return }
        securityScopedRoot = root
        await openProject(at: root)
    }

    /// Re-walks the full tree, re-indexing every file found and removing any indexed
    /// file that no longer exists on disk (catches deletes/renames missed while the app
    /// wasn't watching). Exactly the initial-build walk plus one diff step — the same
    /// primitive used by FSEvents batches and the initial build, not a separate
    /// implementation.
    func fullReindex() async {
        guard let root = projectRoot else { return }
        let found = Set(Self.discoverMarkdownFiles(under: root))

        for url in found {
            await graphIndex.reindex(url: url, action: .addOrUpdate)
        }
        let indexed = await graphIndex.indexedURLs()
        for stale in indexed.subtracting(found) {
            await graphIndex.reindex(url: stale, action: .remove)
        }
        snapshot = await graphIndex.snapshot()
        rootFileTreeNode = FileTreeNode(url: root, isDirectory: true)
    }

    /// Starts the FSEvents watcher for `root`. Every path in one callback batch is
    /// processed, then exactly one snapshot + republish (and one `treeGeneration` bump,
    /// if any directory event occurred) happens at the end of that batch — not
    /// per-file — so a large burst of external changes doesn't thrash the UI.
    private func startWatching(root: URL) {
        let watcher = FileWatcher { [weak self] batch in
            Task { @MainActor in
                await self?.handle(batch: batch)
            }
        }
        watcher.start(root: root)
        fileWatcher = watcher
    }

    private func handle(batch: FileWatcher.Batch) async {
        guard !batch.markdownFiles.isEmpty || !batch.directoryPaths.isEmpty else { return }

        for path in Set(batch.markdownFiles) {
            let url = URL(fileURLWithPath: path)
            let action: ReindexAction = FileManager.default.fileExists(atPath: path) ? .addOrUpdate : .remove
            await graphIndex.reindex(url: url, action: action)
        }
        if !batch.markdownFiles.isEmpty {
            snapshot = await graphIndex.snapshot()
        }
        if !batch.directoryPaths.isEmpty, let root = projectRoot {
            rootFileTreeNode = FileTreeNode(url: root, isDirectory: true)
            treeGeneration += 1
        }
    }

    /// The root's home page, by convention `index.md` directly under the project root
    /// (not searched recursively — only the top-level root counts). Matched
    /// case-insensitively so `Index.md` on a case-sensitive volume is still found.
    nonisolated static func indexFileURL(in root: URL) -> URL? {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        return contents.first { $0.lastPathComponent.lowercased() == "index.md" }
    }

    /// All `.md` files under `root`, found via a recursive directory walk — the same
    /// mechanism used to build the sidebar tree and the id index (no separate mechanism).
    nonisolated static func discoverMarkdownFiles(under root: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var results: [URL] = []
        for case let url as URL in enumerator where url.pathExtension.lowercased() == "md" {
            results.append(url)
        }
        return results
    }
}
