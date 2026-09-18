import Foundation
import CryptoKit

/// Persists a project's saved dynamic views as JSON in Application Support, keyed to a
/// stable hash of the project root's absolute path (not a security-scoped bookmark,
/// which can change bytes on re-creation — a path hash is simpler and equally
/// sufficient for same-machine-only persistence). Never synced across machines.
@MainActor
final class DynamicViewStore: ObservableObject {
    @Published private(set) var views: [DynamicView] = []

    private var storeURL: URL?

    func load(forProjectRoot root: URL) {
        let url = Self.storeURL(forProjectRoot: root)
        storeURL = url

        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([DynamicView].self, from: data) else {
            views = []
            return
        }
        views = decoded
    }

    func save(_ view: DynamicView) {
        if let index = views.firstIndex(where: { $0.id == view.id }) {
            views[index] = view
        } else {
            views.append(view)
        }
        persist()
    }

    func delete(id: UUID) {
        views.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        guard let storeURL else { return }
        guard let data = try? JSONEncoder().encode(views) else { return }
        try? FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: storeURL)
    }

    private static func storeURL(forProjectRoot root: URL) -> URL {
        let hash = SHA256.hash(data: Data(root.standardizedFileURL.path.utf8))
        let hex = hash.map { String(format: "%02x", $0) }.joined().prefix(16)

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport
            .appendingPathComponent("KGE")
            .appendingPathComponent(String(hex))
            .appendingPathComponent("dynamic-views.json")
    }
}
