import Foundation
import Testing
@testable import KGE

@Suite("FileTreeNode laziness")
struct FileTreeNodeTests {
    /// Builds a synthetic nested fixture: `depth` levels, `fanout` subdirectories per
    /// level, one `.md` file per directory. Not committed — built ad hoc for this check.
    private func makeNestedFixture(depth: Int, fanout: Int) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        func populate(_ dir: URL, remainingDepth: Int) throws {
            try "leaf".write(to: dir.appendingPathComponent("note.md"), atomically: true, encoding: .utf8)
            guard remainingDepth > 0 else { return }
            for i in 0..<fanout {
                let sub = dir.appendingPathComponent("dir\(i)")
                try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
                try populate(sub, remainingDepth: remainingDepth - 1)
            }
        }
        try populate(root, remainingDepth: depth)
        return root
    }

    @Test("accessing children only reads that node's own directory, not the whole subtree")
    func childrenAccessIsShallow() throws {
        // 4 levels deep, 10-way fanout at each level: thousands of files/folders total.
        let root = try makeNestedFixture(depth: 4, fanout: 10)
        defer { try? FileManager.default.removeItem(at: root) }

        FileTreeNode.directoryReadCount = 0
        let rootNode = FileTreeNode(url: root, isDirectory: true)

        // "Expand only the root": access its children once.
        let kids = rootNode.children
        #expect(FileTreeNode.directoryReadCount == 1)
        #expect(kids?.count == 11) // 10 subdirectories + this level's own note.md

        // Re-accessing is served from cache: no additional filesystem reads.
        _ = rootNode.children
        #expect(FileTreeNode.directoryReadCount == 1)

        // Descending into one child triggers exactly one more read, for that child only
        // — sibling subtrees remain untouched.
        if let firstDir = kids?.first(where: { $0.isDirectory }) {
            _ = firstDir.children
            #expect(FileTreeNode.directoryReadCount == 2)
        }
    }
}
