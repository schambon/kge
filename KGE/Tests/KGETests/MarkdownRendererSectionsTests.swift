import Foundation
import Testing
@testable import KGE

@Suite("MarkdownRenderer sections")
struct MarkdownRendererSectionsTests {
    @Test("shows forward links and backlinks for interlinked notes")
    func showsForwardLinksAndBacklinks() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let aURL = dir.appendingPathComponent("a.md")
        let bURL = dir.appendingPathComponent("b.md")
        try "---\nid: a\ntype: note\n---\nSee [[note:b]].".write(to: aURL, atomically: true, encoding: .utf8)
        try "---\nid: b\ntype: note\n---\nNo outgoing links.".write(to: bURL, atomically: true, encoding: .utf8)

        let index = GraphIndex()
        await index.reindex(url: aURL, action: .addOrUpdate)
        await index.reindex(url: bURL, action: .addOrUpdate)
        let snapshot = await index.snapshot()

        let aHTML = MarkdownRenderer.renderPage(for: MarkdownFile(url: aURL), snapshot: snapshot)
        #expect(aHTML.contains("id=\"kge-forwardlinks\""))
        #expect(aHTML.contains(">b<"))

        let bHTML = MarkdownRenderer.renderPage(for: MarkdownFile(url: bURL), snapshot: snapshot)
        #expect(bHTML.contains("id=\"kge-backlinks\""))
        #expect(bHTML.contains(">a<"))
    }

    @Test("an id-less file has no backlinks section content, by construction")
    func idLessFileHasNoBacklinks() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let url = dir.appendingPathComponent("plain.md")
        try "No frontmatter here.".write(to: url, atomically: true, encoding: .utf8)

        let index = GraphIndex()
        await index.reindex(url: url, action: .addOrUpdate)
        let snapshot = await index.snapshot()

        let html = MarkdownRenderer.renderPage(for: MarkdownFile(url: url), snapshot: snapshot)
        #expect(!html.contains("id=\"kge-backlinks\""))
    }
}
