import Foundation
import Testing
@testable import KGE

/// Sanity-checks the manual-testing fixture at `Tests/SampleVault` — not exhaustive,
/// just confirms the vault indexes without crashing and demonstrates the features it's
/// meant to: resolved/shorthand links, a duplicate id, an unresolved link, backlinks,
/// and an id-less file. Keeps the fixture from silently bit-rotting.
@Suite("Sample vault fixture")
struct SampleVaultTests {
    /// `Tests/SampleVault`, resolved relative to this test file rather than the current
    /// working directory (which varies by how tests are invoked).
    private static var vaultURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // KGETests/
            .deletingLastPathComponent() // Tests/
            .appendingPathComponent("SampleVault")
    }

    private func buildIndex() async -> (GraphIndex, IndexSnapshot) {
        let index = GraphIndex()
        for url in ProjectController.discoverMarkdownFiles(under: Self.vaultURL) {
            await index.reindex(url: url, action: .addOrUpdate)
        }
        return (index, await index.snapshot())
    }

    @Test("indexes every node and resolves shorthand and full type spellings to the same key")
    func indexesExpectedNodes() async {
        let (_, snapshot) = await buildIndex()

        #expect(snapshot.idIndex["project:mdv"]?.count == 1)
        #expect(snapshot.idIndex["project:kge"]?.count == 1)
        #expect(snapshot.idIndex["project:old-tool"]?.count == 1)
        #expect(snapshot.idIndex["person:alice"]?.count == 1)
        #expect(snapshot.idIndex["person:bob"]?.count == 1)
        #expect(snapshot.idIndex["org:acme"]?.count == 1)
    }

    @Test("the duplicate id resolves to both files")
    func duplicateIdResolvesToBothFiles() async {
        let (_, snapshot) = await buildIndex()
        #expect(snapshot.idIndex["note:dup"]?.count == 2)
    }

    @Test("mdv has backlinks from kge, alice, bob, and the orphan note")
    func mdvHasExpectedBacklinks() async {
        let (_, snapshot) = await buildIndex()
        let backlinks = snapshot.backlinkIndex["project:mdv"] ?? []
        #expect(backlinks.contains { $0.lastPathComponent == "kge.md" })
        #expect(backlinks.contains { $0.lastPathComponent == "alice.md" })
        #expect(backlinks.contains { $0.lastPathComponent == "orphan.md" })
    }

    @Test("an unresolved link and an id-less file render without crashing")
    func rendersUnresolvedAndIdLessFilesSafely() async {
        let (_, snapshot) = await buildIndex()

        let unresolvedFile = MarkdownFile(url: Self.vaultURL.appendingPathComponent("notes/unresolved-demo.md"))
        let unresolvedHTML = MarkdownRenderer.renderPage(for: unresolvedFile, snapshot: snapshot)
        #expect(unresolvedHTML.contains("kge-unresolved"))

        let orphanFile = MarkdownFile(url: Self.vaultURL.appendingPathComponent("notes/orphan.md"))
        let orphanHTML = MarkdownRenderer.renderPage(for: orphanFile, snapshot: snapshot)
        #expect(!orphanHTML.contains("id=\"kge-backlinks\"")) // id-less file: no backlinks section

        let mdvFile = MarkdownFile(url: Self.vaultURL.appendingPathComponent("projects/mdv.md"))
        let mdvHTML = MarkdownRenderer.renderPage(for: mdvFile, snapshot: snapshot)
        #expect(mdvHTML.contains("<table>")) // GFM table
        #expect(mdvHTML.contains("checkbox")) // GFM task list
    }

    @Test("a project-type dynamic view scoped to projects/ includes the nested archived node")
    func dynamicViewMatchesNestedSubtree() async {
        let (_, snapshot) = await buildIndex()
        let view = DynamicView(name: "Projects", typeCanonical: "project", folderRelativePath: "projects")
        let nodes = view.matchingNodes(root: Self.vaultURL, snapshot: snapshot)
        #expect(Set(nodes.map(\.label)) == Set(["mdv", "kge", "old-tool"]))
    }
}
