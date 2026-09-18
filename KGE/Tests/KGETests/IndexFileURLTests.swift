import Foundation
import Testing
@testable import KGE

/// The "home page" convention: opening a folder should land on its root `index.md`,
/// if one exists.
@Suite("ProjectController.indexFileURL")
struct IndexFileURLTests {
    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("finds a root-level index.md")
    func findsRootIndex() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let indexURL = dir.appendingPathComponent("index.md")
        try "Home".write(to: indexURL, atomically: true, encoding: .utf8)

        #expect(ProjectController.indexFileURL(in: dir) == indexURL)
    }

    @Test("matches case-insensitively")
    func matchesCaseInsensitively() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let indexURL = dir.appendingPathComponent("Index.md")
        try "Home".write(to: indexURL, atomically: true, encoding: .utf8)

        #expect(ProjectController.indexFileURL(in: dir) == indexURL)
    }

    @Test("returns nil when there is no root index.md")
    func returnsNilWhenAbsent() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        try "Not the home page".write(to: dir.appendingPathComponent("other.md"), atomically: true, encoding: .utf8)

        #expect(ProjectController.indexFileURL(in: dir) == nil)
    }

    @Test("does not descend into subfolders looking for index.md")
    func doesNotSearchRecursively() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let sub = dir.appendingPathComponent("notes")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try "Nested".write(to: sub.appendingPathComponent("index.md"), atomically: true, encoding: .utf8)

        #expect(ProjectController.indexFileURL(in: dir) == nil)
    }
}
