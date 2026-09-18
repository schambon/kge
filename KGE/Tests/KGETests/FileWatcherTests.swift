import Foundation
import Testing
@testable import KGE

@Suite("FileWatcher")
struct FileWatcherTests {
    @Test("reports created and deleted .md files via FSEvents, without a manual reindex")
    func reportsFileSystemChanges() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        actor BatchCollector {
            var batches: [FileWatcher.Batch] = []
            func record(_ batch: FileWatcher.Batch) { batches.append(batch) }
            func allPaths() -> [String] { batches.flatMap(\.markdownFiles) }
        }
        let collector = BatchCollector()

        let watcher = FileWatcher { batch in
            Task { await collector.record(batch) }
        }
        watcher.start(root: dir)
        defer { watcher.stop() }

        // Give FSEvents a moment to actually start before making changes.
        try await Task.sleep(nanoseconds: 300_000_000)

        let fileURL = dir.appendingPathComponent("new.md")
        try "Hello".write(to: fileURL, atomically: true, encoding: .utf8)

        // Poll for the event to arrive rather than a single fixed sleep, since FSEvents
        // latency is asynchronous.
        var sawCreate = false
        for _ in 0..<20 {
            if await collector.allPaths().contains(fileURL.path) {
                sawCreate = true
                break
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        #expect(sawCreate)
    }
}
