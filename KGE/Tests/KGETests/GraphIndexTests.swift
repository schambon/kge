import Foundation
import Testing
@testable import KGE

@Suite("GraphIndex")
struct GraphIndexTests {
    private func write(_ content: String, name: String, in dir: URL) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("indexes distinct ids and surfaces duplicates")
    func indexesAndSurfacesDuplicates() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let a = try write("---\nid: alpha\ntype: project\n---\nBody A", name: "a.md", in: dir)
        let b = try write("---\nid: beta\ntype: project\n---\nBody B", name: "b.md", in: dir)
        let c1 = try write("---\nid: gamma\ntype: project\n---\nBody C1", name: "c1.md", in: dir)
        let c2 = try write("---\nid: gamma\ntype: project\n---\nBody C2", name: "c2.md", in: dir)

        let index = GraphIndex()
        for url in [a, b, c1, c2] {
            await index.reindex(url: url, action: .addOrUpdate)
        }
        let snapshot = await index.snapshot()

        #expect(snapshot.idIndex["project:alpha"] == [a])
        #expect(snapshot.idIndex["project:beta"] == [b])
        #expect(Set(snapshot.idIndex["project:gamma"] ?? []) == Set([c1, c2]))
    }

    @Test("backlinks: A links to B means B's backlinks contain A")
    func backlinksInvertOutgoingLinks() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let a = try write("---\nid: a\ntype: note\n---\nSee [[note:b]].", name: "a.md", in: dir)
        let b = try write("---\nid: b\ntype: note\n---\nNo outgoing links.", name: "b.md", in: dir)

        let index = GraphIndex()
        for url in [a, b] {
            await index.reindex(url: url, action: .addOrUpdate)
        }
        let snapshot = await index.snapshot()

        #expect(snapshot.backlinkIndex["note:b"] == [a])
    }

    @Test("reindex is idempotent across add -> remove -> re-add")
    func reindexIdempotency() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let a = try write("---\nid: a\ntype: note\n---\nSee [[note:b]].", name: "a.md", in: dir)
        let b = try write("---\nid: b\ntype: note\n---\nBody", name: "b.md", in: dir)

        let index = GraphIndex()
        await index.reindex(url: a, action: .addOrUpdate)
        await index.reindex(url: b, action: .addOrUpdate)

        await index.reindex(url: a, action: .remove)
        var snapshot = await index.snapshot()
        #expect(snapshot.idIndex["note:a"] == nil)
        #expect(snapshot.backlinkIndex["note:b"] == nil)

        await index.reindex(url: a, action: .addOrUpdate)
        snapshot = await index.snapshot()
        #expect(snapshot.idIndex["note:a"] == [a])
        #expect(snapshot.backlinkIndex["note:b"] == [a])
    }

    @Test("malformed frontmatter degrades to id-less file, never crashes")
    func malformedFrontmatterDegrades() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let url = try write("---\nid: [broken yaml\n---\nBody", name: "broken.md", in: dir)

        let index = GraphIndex()
        await index.reindex(url: url, action: .addOrUpdate)
        let snapshot = await index.snapshot()

        #expect(snapshot.records[url]?.canonicalKey == nil)
    }
}
