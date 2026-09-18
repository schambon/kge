import Foundation

/// Persists a security-scoped bookmark to the last-opened project root, so the app can
/// restore it on relaunch without re-prompting via `NSOpenPanel`. Strictly local
/// (`UserDefaults`) — this is a convenience, not something the brief requires syncing
/// anywhere.
enum ProjectBookmarkStore {
    private static let defaultsKey = "KGELastProjectBookmark"

    static func save(_ url: URL) {
        guard let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    /// Resolves the last-saved bookmark, if any, and starts accessing its
    /// security-scoped resource. The caller is responsible for calling
    /// `stopAccessingSecurityScopedResource()` on the returned URL when the project
    /// closes or a new one is opened.
    static func restoreLastProject() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return nil }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }

        guard url.startAccessingSecurityScopedResource() else { return nil }
        if isStale {
            save(url)
        }
        return url
    }
}
