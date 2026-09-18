import Foundation
import Yams

/// Whether a reindex call should (re)parse and splice a file into the index, or just
/// remove its prior contributions.
enum ReindexAction {
    case addOrUpdate
    case remove
}

/// An immutable copy of the index's state, handed to the `@MainActor` UI layer after
/// each batch of changes. The UI never talks to `GraphIndex` directly for rendering,
/// only via snapshots, so rendering stays synchronous/cheap on the main actor.
struct IndexSnapshot: Sendable {
    struct FileRecord: Sendable {
        var frontmatter: Frontmatter?
        var canonicalKey: String?
        var outgoingKeys: [String]
    }

    var records: [URL: FileRecord] = [:]
    var idIndex: [String: [URL]] = [:]
    var backlinkIndex: [String: Set<URL>] = [:]

    /// The display label for a URL: filename minus `.md`.
    static func displayLabel(for url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
    }
}

/// The in-memory id index and backlink graph, built asynchronously and never persisted
/// to disk between launches. An `actor` so background-thread writes (initial indexing,
/// FSEvents-driven updates) and main-thread reads (via `snapshot()`) are both safe.
actor GraphIndex {
    private var records: [URL: IndexSnapshot.FileRecord] = [:]
    private var idIndex: [String: [URL]] = [:]
    private var backlinkIndex: [String: Set<URL>] = [:]

    /// The single shared primitive: "(re)parse this one file, splice its id/type and
    /// outgoing links into the index." Used identically by initial indexing, FSEvents
    /// incremental updates, and manual reindex — none of them touch the dictionaries
    /// directly.
    func reindex(url: URL, action: ReindexAction) {
        // Step 1: un-splice old contributions first, unconditionally. This makes
        // add/update/remove share code and makes the whole operation idempotent.
        let old = records[url]
        if let oldKey = old?.canonicalKey {
            idIndex[oldKey]?.removeAll { $0 == url }
            if idIndex[oldKey]?.isEmpty == true {
                idIndex[oldKey] = nil
            }
        }
        for target in old?.outgoingKeys ?? [] {
            backlinkIndex[target]?.remove(url)
            if backlinkIndex[target]?.isEmpty == true {
                backlinkIndex[target] = nil
            }
        }
        records[url] = nil

        guard action == .addOrUpdate else { return }

        guard let raw = try? String(contentsOf: url, encoding: .utf8) else {
            // File vanished between the FSEvents callback and this read: treat as removed.
            return
        }

        let (yaml, body) = FrontmatterScanner.splitFrontmatter(raw)
        let frontmatter: Frontmatter? = yaml.flatMap { yamlText in
            try? YAMLDecoder().decode(Frontmatter.self, from: yamlText)
        }

        var canonicalKey: String?
        if let id = frontmatter?.id, let type = frontmatter?.type, !id.isEmpty, !type.isEmpty {
            canonicalKey = "\(TypeShorthand.expand(type)):\(id)"
        }

        let occurrences = WikiLinkScanner.scanWikiLinks(in: body)
        let outgoingKeys = occurrences.map { "\(TypeShorthand.expand($0.typeShorthand)):\($0.id)" }

        records[url] = IndexSnapshot.FileRecord(
            frontmatter: frontmatter,
            canonicalKey: canonicalKey,
            outgoingKeys: outgoingKeys
        )

        if let canonicalKey {
            idIndex[canonicalKey, default: []].append(url)
        }
        for target in outgoingKeys {
            backlinkIndex[target, default: []].insert(url)
        }
    }

    /// All URLs currently represented in the index — used by manual/full reindex to
    /// diff against a fresh directory walk and remove entries for deleted/renamed files.
    func indexedURLs() -> Set<URL> {
        Set(records.keys)
    }

    func snapshot() -> IndexSnapshot {
        IndexSnapshot(records: records, idIndex: idIndex, backlinkIndex: backlinkIndex)
    }
}
