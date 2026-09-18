import Foundation
import Testing
@testable import KGE

@Suite("MarkdownRenderer")
struct MarkdownRendererTests {
    @Test("renders tables, code blocks, and task lists")
    func rendersGFMFeatures() throws {
        let markdown = """
        ---
        id: note1
        type: project
        ---
        # Title

        | A | B |
        |---|---|
        | 1 | 2 |

        ```swift
        let x = 1
        ```

        - [ ] todo item
        - [x] done item
        """

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("note1.md")
        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)

        let html = MarkdownRenderer.renderPage(for: MarkdownFile(url: fileURL), snapshot: IndexSnapshot())

        #expect(html.contains("<table>"))
        #expect(html.contains("<code"))
        #expect(html.contains("checkbox"))
        // Frontmatter must not leak into rendered body.
        #expect(!html.contains("type: project"))
    }
}
