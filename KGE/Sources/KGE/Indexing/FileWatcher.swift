import Foundation
import CoreServices

/// Watches a single project root recursively via FSEvents (the CoreServices
/// recursive-directory-watching API), not kqueue/DispatchSource — kqueue needs one
/// watch per directory and silently drops events past a few thousand watched
/// directories, while FSEvents watches the whole subtree from one stream regardless of
/// file or folder count.
///
/// Classification is deliberately simplified to sidestep FSEvents' fiddly flag
/// combinations: for every reported path, this just asks whether the path currently
/// exists on disk — the caller doesn't need to interpret create/modify/rename flags,
/// since `GraphIndex.reindex` is idempotent and always re-reads from disk anyway.
final class FileWatcher {
    /// A batch of raw paths reported by one FSEvents callback invocation, split into
    /// `.md` files (to feed the shared reindex primitive) and directories (which bump
    /// the sidebar's tree generation instead).
    struct Batch {
        var markdownFiles: [String] = []
        var directoryPaths: [String] = []
    }

    private var stream: FSEventStreamRef?
    private let onBatch: (Batch) -> Void

    init(onBatch: @escaping (Batch) -> Void) {
        self.onBatch = onBatch
    }

    func start(root: URL) {
        stop()

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, clientCallBackInfo, numEvents, eventPaths, eventFlags, _ in
            guard let clientCallBackInfo else { return }
            let watcher = Unmanaged<FileWatcher>.fromOpaque(clientCallBackInfo).takeUnretainedValue()
            let pathsPointer = eventPaths.assumingMemoryBound(to: UnsafePointer<CChar>.self)

            var batch = Batch()
            for i in 0..<numEvents {
                let path = String(cString: pathsPointer[i])
                let flags = eventFlags[i]
                let isDirectoryEvent = (flags & UInt32(kFSEventStreamEventFlagItemIsDir)) != 0
                if isDirectoryEvent {
                    batch.directoryPaths.append(path)
                } else if path.lowercased().hasSuffix(".md") {
                    batch.markdownFiles.append(path)
                }
            }
            watcher.onBatch(batch)
        }

        let newStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [root.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3, // latency: batch bursts of changes together
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        )

        guard let newStream else { return }
        stream = newStream
        FSEventStreamSetDispatchQueue(newStream, DispatchQueue(label: "com.kge.filewatcher"))
        FSEventStreamStart(newStream)
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit {
        stop()
    }
}
