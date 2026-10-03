import Foundation
import Testing
@testable import KGE

@Suite("DynamicView matching")
struct DynamicViewMatchingTests {
    @Test("matches nodes of the given type within the folder subtree, not siblings")
    func matchesSubtreeOnly() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sub = dir.appendingPathComponent("projects")
        let subDeep = sub.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: subDeep, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let inSub = sub.appendingPathComponent("a.md")
        let inNested = subDeep.appendingPathComponent("b.md")
        let outside = dir.appendingPathComponent("c.md")

        try "---\nid: a\ntype: project\n---\nBody".write(to: inSub, atomically: true, encoding: .utf8)
        try "---\nid: b\ntype: project\n---\nBody".write(to: inNested, atomically: true, encoding: .utf8)
        try "---\nid: c\ntype: project\n---\nBody".write(to: outside, atomically: true, encoding: .utf8)

        let index = GraphIndex()
        for url in [inSub, inNested, outside] {
            await index.reindex(url: url, action: .addOrUpdate)
        }
        let snapshot = await index.snapshot()

        let view = DynamicView(name: "Projects", folderRelativePath: "projects", criteria: [ViewCriterion(key: "type", value: "project")])
        let nodes = view.matchingNodes(root: dir, snapshot: snapshot)

        #expect(Set(nodes.map(\.url)) == Set([inSub, inNested]))
    }

    @Test("empty folderRelativePath matches the whole project root")
    func emptyFolderMatchesRoot() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let a = dir.appendingPathComponent("a.md")
        try "---\nid: a\ntype: note\n---\nBody".write(to: a, atomically: true, encoding: .utf8)

        let index = GraphIndex()
        await index.reindex(url: a, action: .addOrUpdate)
        let snapshot = await index.snapshot()

        let view = DynamicView(name: "All notes", folderRelativePath: "", criteria: [ViewCriterion(key: "type", value: "note")])
        let nodes = view.matchingNodes(root: dir, snapshot: snapshot)

        #expect(nodes.map(\.url) == [a])
    }
}

@Suite("DynamicViewStore")
@MainActor
struct DynamicViewStoreTests {
    @Test("save, load, and delete round-trip against a temp Application Support directory")
    func saveLoadDeleteRoundTrip() throws {
        // Use a distinct fake project root per test run so stores don't collide.
        let fakeRoot = URL(fileURLWithPath: "/tmp/kge-test-\(UUID().uuidString)")

        let store = DynamicViewStore()
        store.load(forProjectRoot: fakeRoot)
        #expect(store.views.isEmpty)

        let view = DynamicView(name: "My View", folderRelativePath: "", criteria: [ViewCriterion(key: "type", value: "project")])
        store.save(view)
        #expect(store.views.count == 1)

        // A fresh store instance loading the same root sees the persisted view.
        let reloaded = DynamicViewStore()
        reloaded.load(forProjectRoot: fakeRoot)
        #expect(reloaded.views.first?.name == "My View")

        reloaded.delete(id: view.id)
        #expect(reloaded.views.isEmpty)

        let reloadedAgain = DynamicViewStore()
        reloadedAgain.load(forProjectRoot: fakeRoot)
        #expect(reloadedAgain.views.isEmpty)
    }
}

@Suite("DynamicView attribute criteria")
struct DynamicViewCriteriaTests {
    @Test("type + attribute criteria are ANDed; legacy typeCanonical JSON still decodes")
    func attributeCriteria() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let alive = dir.appendingPathComponent("alice.md")
        let dead = dir.appendingPathComponent("bob.md")
        let project = dir.appendingPathComponent("p.md")
        try "---\nid: a\ntype: person\nstatus: alive\n---\n".write(to: alive, atomically: true, encoding: .utf8)
        try "---\nid: b\ntype: person\nstatus: dead\n---\n".write(to: dead, atomically: true, encoding: .utf8)
        try "---\nid: p\ntype: project\nstatus: alive\n---\n".write(to: project, atomically: true, encoding: .utf8)

        let index = GraphIndex()
        for url in [alive, dead, project] { await index.reindex(url: url, action: .addOrUpdate) }
        let snapshot = await index.snapshot()

        let view = DynamicView(name: "Living", folderRelativePath: "", criteria: [
            ViewCriterion(key: "type", value: "person"),
            ViewCriterion(key: "status", value: "alive"),
        ])
        #expect(view.matchingNodes(root: dir, snapshot: snapshot).map(\.url) == [alive])

        let legacy = Data(#"{"id":"\#(UUID().uuidString)","name":"Old","typeCanonical":"project","folderRelativePath":""}"#.utf8)
        let decoded = try JSONDecoder().decode(DynamicView.self, from: legacy)
        #expect(decoded.criteria.map(\.value) == ["project"])
        #expect(decoded.labelStyle == .fileName)
    }
}

@Suite("DynamicView link labels")
struct DynamicViewLabelTests {
    @Test("labels follow labelStyle: file name, id, title with fallback")
    func labelStyles() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let titled = dir.appendingPathComponent("with-title.md")
        let untitled = dir.appendingPathComponent("no-title.md")
        try "---\nid: t1\ntype: note\n---\n\nIntro\n\n## My Title ##\n".write(to: titled, atomically: true, encoding: .utf8)
        try "---\nid: t2\ntype: note\n---\n```\n# not a heading\n```\nBody".write(to: untitled, atomically: true, encoding: .utf8)

        let index = GraphIndex()
        for url in [titled, untitled] { await index.reindex(url: url, action: .addOrUpdate) }
        let snapshot = await index.snapshot()

        func labels(_ style: LinkLabelStyle) -> [URL: String] {
            let view = DynamicView(name: "v", folderRelativePath: "", criteria: [ViewCriterion(key: "type", value: "note")], labelStyle: style)
            return Dictionary(uniqueKeysWithValues: view.matchingNodes(root: dir, snapshot: snapshot).map { ($0.url, $0.label) })
        }
        #expect(labels(.fileName)[titled] == "with-title")
        #expect(labels(.id)[titled] == "t1")
        #expect(labels(.title)[titled] == "My Title")
        #expect(labels(.title)[untitled] == "no-title")
    }

    @Test("labelStyle round-trips through Codable")
    func codableRoundTrip() throws {
        let view = DynamicView(name: "v", folderRelativePath: "", criteria: [], labelStyle: .title)
        let decoded = try JSONDecoder().decode(DynamicView.self, from: JSONEncoder().encode(view))
        #expect(decoded.labelStyle == .title)
    }
}
