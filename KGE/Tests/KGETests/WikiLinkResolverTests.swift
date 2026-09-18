import Foundation
import Testing
@testable import KGE

@Suite("WikiLinkResolver")
struct WikiLinkResolverTests {
    private let resolvedURL = URL(fileURLWithPath: "/vault/mdv.md")
    private let duplicateURLs = [
        URL(fileURLWithPath: "/vault/dup1.md"),
        URL(fileURLWithPath: "/vault/dup2.md")
    ]

    private func makeSnapshot() -> IndexSnapshot {
        var snapshot = IndexSnapshot()
        snapshot.idIndex["project:mdv"] = [resolvedURL]
        snapshot.idIndex["project:dup"] = duplicateURLs
        return snapshot
    }

    @Test("resolves a single match to a markdown link with kge:// href")
    func resolvesSingleMatch() {
        let body = "See [[proj:mdv]] for details."
        let result = WikiLinkResolver.resolve(body: body, snapshot: makeSnapshot())

        #expect(result.contains("[mdv]("))
        #expect(result.contains("kge://open?path=/vault/mdv.md"))
    }

    @Test("respects an explicit |label override for a single match")
    func respectsLabelOverride() {
        let body = "[[proj:mdv|The mdv project]]"
        let result = WikiLinkResolver.resolve(body: body, snapshot: makeSnapshot())

        #expect(result.contains("[The mdv project]("))
    }

    @Test("renders duplicate ids as two anchors joined by a pipe")
    func rendersDuplicatesAsMultipleAnchors() {
        let body = "[[proj:dup]]"
        let result = WikiLinkResolver.resolve(body: body, snapshot: makeSnapshot())

        #expect(result.contains("dup1</a> | <a"))
        #expect(result.contains("kge://open?path=/vault/dup1.md"))
        #expect(result.contains("kge://open?path=/vault/dup2.md"))
    }

    @Test("renders zero matches as an unresolved span")
    func rendersUnresolvedAsSpan() {
        let body = "[[proj:missing]]"
        let result = WikiLinkResolver.resolve(body: body, snapshot: makeSnapshot())

        #expect(result.contains("kge-unresolved"))
        #expect(result.contains("proj:missing"))
    }

    @Test("leaves plain text without wiki-links unchanged")
    func leavesPlainTextUnchanged() {
        let body = "No links here."
        let result = WikiLinkResolver.resolve(body: body, snapshot: makeSnapshot())

        #expect(result == body)
    }
}
