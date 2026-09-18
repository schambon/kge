import Foundation
import Testing
@testable import KGE

/// Exercises the same add -> remove -> re-add sequence FSEvents batches drive, but
/// through `ProjectController`'s `fullReindex()` — the diff-based re-walk that manual
/// reindex and (conceptually) FSEvents batches both reduce to.
@Suite("ProjectController reindexing")
@MainActor
struct ProjectControllerReindexTests {
    @Test("fullReindex picks up new files and drops deleted ones")
    func fullReindexTracksFilesystemChanges() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let aURL = dir.appendingPathComponent("a.md")
        try "---\nid: a\ntype: note\n---\nBody".write(to: aURL, atomically: true, encoding: .utf8)

        let controller = ProjectController()
        await controller.openProject(at: dir)
        #expect(controller.snapshot.idIndex["note:a"] == [aURL])

        // A file appears on disk (as if created externally while the app was closed).
        let bURL = dir.appendingPathComponent("b.md")
        try "---\nid: b\ntype: note\n---\nBody".write(to: bURL, atomically: true, encoding: .utf8)
        await controller.fullReindex()
        #expect(controller.snapshot.idIndex["note:b"] == [bURL])

        // A file disappears from disk.
        try FileManager.default.removeItem(at: aURL)
        await controller.fullReindex()
        #expect(controller.snapshot.idIndex["note:a"] == nil)
        #expect(controller.snapshot.records[aURL] == nil)
        #expect(controller.snapshot.idIndex["note:b"] == [bURL]) // untouched
    }
}
