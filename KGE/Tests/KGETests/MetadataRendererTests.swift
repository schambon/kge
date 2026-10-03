import Foundation
import Testing
@testable import KGE

@Suite("MetadataRenderer")
struct MetadataRendererTests {
    @Test("renders scalars, lists and nested maps in file order")
    func rendersAllShapes() {
        let html = MetadataRenderer.render(yaml: """
        id: n1
        type: project
        tags: [a, b]
        owner:
          name: Ann
          team: core
        """)
        #expect(html.contains("<dt>id</dt><dd>n1</dd>"))
        #expect(html.contains("<dt>type</dt><dd>project</dd>"))
        #expect(html.contains("<ul><li>a</li><li>b</li></ul>"))
        #expect(html.contains("<dt>name</dt><dd>Ann</dd>"))
        #expect(html.range(of: "<dt>id</dt>")!.lowerBound < html.range(of: "<dt>owner</dt>")!.lowerBound)
    }

    @Test("escapes HTML in keys and values")
    func escapes() {
        let html = MetadataRenderer.render(yaml: "\"a<b\": \"<script>x</script> & q\"")
        #expect(!html.contains("<script>"))
        #expect(html.contains("a&lt;b"))
        #expect(html.contains("&amp;"))
    }

    @Test("no or invalid frontmatter renders nothing")
    func empty() {
        #expect(MetadataRenderer.render(yaml: nil) == "")
        #expect(MetadataRenderer.render(yaml: "just text: [") == "")
    }

    @Test("node page header includes all frontmatter")
    func pageIntegration() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("n.md")
        try "---\nid: n1\ntype: project\nstatus: active\n---\nBody".write(to: url, atomically: true, encoding: .utf8)
        let html = MarkdownRenderer.renderPage(for: MarkdownFile(url: url), snapshot: IndexSnapshot())
        #expect(html.contains("<dt>status</dt><dd>active</dd>"))
    }
}
