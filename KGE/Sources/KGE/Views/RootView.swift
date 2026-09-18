import SwiftUI

/// What's currently shown in the content pane: a rendered node, or a dynamic view
/// (transient/unsaved when `savedID == nil`, otherwise the id of the saved view it
/// matches — this is what drives the title bar's save/trash icon toggle).
private enum ContentKind: Equatable {
    case node(URL)
    case dynamicView(savedID: UUID?, typeCanonical: String, folderRelativePath: String)
}

/// Top-level split view: sidebar (file tree / dynamic views) + content pane (rendered node).
///
/// M8 state: dynamic views are wired end to end (builder, save/delete, sidebar +
/// quick-open integration). Live FSEvents watching is still to come (M9).
///
/// Navigation flows through a single path: every entry point (wiki-link clicks, sidebar
/// selection, quick-open, B/L popover selection) sets `currentURL`; `onChange` is the
/// one place that renders and records history, guarded by `isNavigatingHistory` so
/// back/forward traversal (which also sets `currentURL`, to reuse the same render path)
/// doesn't re-push the entry it's replaying.
struct RootView: View {
    @StateObject private var projectController = ProjectController()
    @StateObject private var appState = AppState()
    @StateObject private var findController = FindController()
    @StateObject private var dynamicViewStore = DynamicViewStore()

    @State private var currentURL: URL?
    @State private var contentKind: ContentKind?
    @State private var currentHTML: String = HTMLTemplate.renderPage(
        title: "KGE",
        slug: "",
        bodyHTML: "<p>Open a folder to get started.</p>",
        forwardLinksHTML: "",
        backlinksHTML: ""
    )
    @State private var currentBaseURL: URL?
    @State private var linksPopover: LinksPopoverKind?
    @State private var history = NavigationHistory()
    @State private var isNavigatingHistory = false
    @State private var isQuickOpenPresented = false

    @State private var isDynamicViewBuilderPresented = false
    @State private var builderType = ""
    @State private var builderFolder = ""
    @State private var isSaveNamePromptPresented = false
    @State private var saveNameDraft = ""

    private let keyEventMonitor = KeyEventMonitor()

    private enum LinksPopoverKind: Identifiable {
        case backlinks
        case forwardLinks
        var id: Self { self }
    }

    var body: some View {
        NavigationSplitView {
            sidebarContent
                .frame(minWidth: 200)
        } detail: {
            ZStack(alignment: .topTrailing) {
                KGEWebViewRepresentable(
                    html: currentHTML,
                    baseURL: currentBaseURL,
                    onOpenNode: { url in currentURL = url },
                    onOpenBacklinks: { linksPopover = .backlinks },
                    onOpenForwardLinks: { linksPopover = .forwardLinks },
                    onWebViewCreated: { webView in findController.webView = webView }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if findController.isVisible {
                    FindBarView(
                        query: $findController.query,
                        onNext: { findController.findNext() },
                        onPrevious: { findController.findPrevious() },
                        onClose: { findController.close() }
                    )
                }
            }
            .toolbar {
                ToolbarItem {
                    Button("Open Folder…") {
                        openFolder()
                    }
                }
                ToolbarItem {
                    dynamicViewToolbarButton
                }
            }
            .popover(item: $linksPopover) { kind in
                switch kind {
                case .backlinks:
                    LinksPopoverView(
                        title: "Backlinks",
                        nodes: currentURL.map { NodeGraphQueries.backlinks(for: $0, snapshot: projectController.snapshot) } ?? [],
                        onSelect: { url in linksPopover = nil; currentURL = url }
                    )
                case .forwardLinks:
                    LinksPopoverView(
                        title: "Forward links",
                        nodes: currentURL.map { NodeGraphQueries.forwardLinks(for: $0, snapshot: projectController.snapshot) } ?? [],
                        onSelect: { url in linksPopover = nil; currentURL = url }
                    )
                }
            }
        }
        .onChange(of: currentURL) { _, newValue in
            guard let newValue else { return }
            contentKind = .node(newValue)
            renderNode(url: newValue)
            if isNavigatingHistory {
                isNavigatingHistory = false
            } else {
                history.push(newValue)
            }
        }
        .onChange(of: builderType) { _, _ in renderTransientDynamicViewIfNeeded() }
        .onChange(of: builderFolder) { _, _ in renderTransientDynamicViewIfNeeded() }
        .onReceive(NotificationCenter.default.publisher(for: .kgeOpenFolderRequested)) { _ in
            openFolder()
        }
        .onReceive(NotificationCenter.default.publisher(for: .kgeFindRequested)) { _ in
            findController.open()
        }
        .onReceive(NotificationCenter.default.publisher(for: .kgeQuickOpenRequested)) { _ in
            isQuickOpenPresented = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .kgeHistoryBackRequested)) { _ in
            goBack()
        }
        .onReceive(NotificationCenter.default.publisher(for: .kgeHistoryForwardRequested)) { _ in
            goForward()
        }
        .onReceive(NotificationCenter.default.publisher(for: .kgeDynamicViewRequested)) { _ in
            openDynamicViewBuilder()
        }
        .onReceive(NotificationCenter.default.publisher(for: .kgeSaveOrDeleteDynamicViewRequested)) { _ in
            saveOrDeleteDynamicView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .kgeReindexRequested)) { _ in
            Task { await projectController.fullReindex() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .kgeRevealInFinderRequested)) { _ in
            revealInFinder()
        }
        .task {
            await projectController.restoreLastProjectIfAvailable()
            if let root = projectController.projectRoot {
                dynamicViewStore.load(forProjectRoot: root)
                openIndexPageIfPresent()
            }
        }
        .onAppear {
            keyEventMonitor.register("s") { appState.focusZone = appState.focusZone == .sidebar ? .content : .sidebar }
            keyEventMonitor.register("/") { findController.open() }
            keyEventMonitor.register("<") { goBack() }
            keyEventMonitor.register(">") { goForward() }
            keyEventMonitor.register("d") { openDynamicViewBuilder() }
            keyEventMonitor.start()
        }
        .onDisappear {
            keyEventMonitor.stop()
        }
        .sheet(isPresented: $isQuickOpenPresented) {
            QuickOpenView(
                snapshot: projectController.snapshot,
                dynamicViews: dynamicViewStore.views,
                onSelect: { url in
                    isQuickOpenPresented = false
                    currentURL = url
                },
                onSelectDynamicView: { view in
                    isQuickOpenPresented = false
                    openSavedDynamicView(view)
                },
                onCancel: { isQuickOpenPresented = false }
            )
        }
        .sheet(isPresented: $isDynamicViewBuilderPresented) {
            DynamicViewBuilderView(
                availableTypes: availableTypes,
                availableFolders: availableFolders,
                typeCanonical: $builderType,
                folderRelativePath: $builderFolder,
                onClose: { isDynamicViewBuilderPresented = false }
            )
        }
        .sheet(isPresented: $isSaveNamePromptPresented) {
            SaveDynamicViewNameView(
                name: $saveNameDraft,
                onSave: { commitSaveDynamicView() },
                onCancel: { isSaveNamePromptPresented = false }
            )
        }
    }

    @ViewBuilder
    private var sidebarContent: some View {
        if let rootNode = projectController.rootFileTreeNode {
            SidebarView(
                rootItems: [.file(rootNode), .dynamicViewsRoot(views: dynamicViewStore.views)],
                selection: $currentURL,
                onSelectDynamicView: { view in openSavedDynamicView(view) }
            )
        } else {
            VStack(spacing: 8) {
                Text("No folder open.")
                    .foregroundStyle(.secondary)
                Button("Open Folder…") {
                    openFolder()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var dynamicViewToolbarButton: some View {
        if case .dynamicView(let savedID, _, _) = contentKind {
            if savedID == nil {
                Button {
                    beginSaveDynamicView()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .help("Save Dynamic View")
            } else {
                Button {
                    saveOrDeleteDynamicView()
                } label: {
                    Image(systemName: "trash")
                }
                .help("Delete Dynamic View")
            }
        }
    }

    private var availableTypes: [String] {
        Set(projectController.snapshot.idIndex.keys.compactMap {
            $0.split(separator: ":", maxSplits: 1).first.map(String.init)
        }).sorted()
    }

    private var availableFolders: [String] {
        guard let root = projectController.projectRoot else { return [] }
        let rootPath = root.standardizedFileURL.path
        let paths = projectController.snapshot.records.keys.map {
            $0.deletingLastPathComponent().standardizedFileURL.path
        }
        let relatives: Set<String> = Set(paths.compactMap { path in
            guard path.hasPrefix(rootPath) else { return nil }
            let rel = String(path.dropFirst(rootPath.count))
            return rel.hasPrefix("/") ? String(rel.dropFirst()) : rel
        })
        return relatives.sorted()
    }

    private func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            await projectController.openProject(at: url)
            dynamicViewStore.load(forProjectRoot: url)
            openIndexPageIfPresent()
        }
    }

    /// Opens the project root's home page — by convention `index.md` directly under the
    /// root — right after a folder is opened, if one exists. Silently does nothing
    /// otherwise, leaving the content pane on its placeholder.
    private func openIndexPageIfPresent() {
        guard let root = projectController.projectRoot,
              let indexURL = ProjectController.indexFileURL(in: root) else { return }
        currentURL = indexURL
    }

    private func renderNode(url: URL) {
        let file = MarkdownFile(url: url)
        currentHTML = MarkdownRenderer.renderPage(for: file, snapshot: projectController.snapshot)
        currentBaseURL = url.deletingLastPathComponent()
    }

    private func goBack() {
        guard let url = history.goBack(), url != currentURL else { return }
        isNavigatingHistory = true
        currentURL = url
    }

    private func goForward() {
        guard let url = history.goForward(), url != currentURL else { return }
        isNavigatingHistory = true
        currentURL = url
    }

    /// Reveals the currently-open node in Finder, or the project root if no node is
    /// open — global, since it makes sense with either pane focused.
    private func revealInFinder() {
        let target = currentURL ?? projectController.projectRoot
        guard let target else { return }
        NSWorkspace.shared.activateFileViewerSelecting([target])
    }

    // MARK: - Dynamic views

    private func openDynamicViewBuilder() {
        guard projectController.projectRoot != nil else { return }
        if builderType.isEmpty {
            builderType = availableTypes.first ?? ""
        }
        if case .node(let url) = contentKind, let root = projectController.projectRoot {
            builderFolder = relativeFolder(of: url, root: root)
        }
        isDynamicViewBuilderPresented = true
        renderTransientDynamicViewIfNeeded()
    }

    private func relativeFolder(of url: URL, root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let folderPath = url.deletingLastPathComponent().standardizedFileURL.path
        guard folderPath.hasPrefix(rootPath) else { return "" }
        let rel = String(folderPath.dropFirst(rootPath.count))
        return rel.hasPrefix("/") ? String(rel.dropFirst()) : rel
    }

    /// Renders the builder's current selection immediately, with no separate "apply"
    /// step — every change to type or folder re-renders live.
    private func renderTransientDynamicViewIfNeeded() {
        guard !builderType.isEmpty, projectController.projectRoot != nil else { return }
        currentURL = nil
        contentKind = .dynamicView(savedID: nil, typeCanonical: builderType, folderRelativePath: builderFolder)
        renderCurrentDynamicView()
    }

    private func openSavedDynamicView(_ view: DynamicView) {
        currentURL = nil
        builderType = view.typeCanonical
        builderFolder = view.folderRelativePath
        contentKind = .dynamicView(savedID: view.id, typeCanonical: view.typeCanonical, folderRelativePath: view.folderRelativePath)
        renderCurrentDynamicView()
    }

    private func renderCurrentDynamicView() {
        guard case .dynamicView(let savedID, let type, let folder) = contentKind,
              let root = projectController.projectRoot else { return }
        let name = savedID.flatMap { id in dynamicViewStore.views.first { $0.id == id }?.name } ?? "Dynamic View"
        let nodes = DynamicView(name: name, typeCanonical: type, folderRelativePath: folder)
            .matchingNodes(root: root, snapshot: projectController.snapshot)
        currentHTML = DynamicViewRenderer.renderPage(name: name, typeCanonical: type, folderRelativePath: folder, nodes: nodes)
        currentBaseURL = nil
    }

    private func beginSaveDynamicView() {
        saveNameDraft = ""
        isSaveNamePromptPresented = true
    }

    private func commitSaveDynamicView() {
        guard case .dynamicView(_, let type, let folder) = contentKind, !saveNameDraft.isEmpty else { return }
        let view = DynamicView(name: saveNameDraft, typeCanonical: type, folderRelativePath: folder)
        dynamicViewStore.save(view)
        contentKind = .dynamicView(savedID: view.id, typeCanonical: type, folderRelativePath: folder)
        isSaveNamePromptPresented = false
    }

    /// Cmd-S: save the current transient dynamic view, or delete it if it's already
    /// saved — the title-bar icon toggles between the two states.
    private func saveOrDeleteDynamicView() {
        guard case .dynamicView(let savedID, let type, let folder) = contentKind else { return }
        if let savedID {
            dynamicViewStore.delete(id: savedID)
            contentKind = .dynamicView(savedID: nil, typeCanonical: type, folderRelativePath: folder)
        } else {
            beginSaveDynamicView()
        }
    }
}

/// The name-entry sheet shown when saving a transient dynamic view for the first time.
private struct SaveDynamicViewNameView: View {
    @Binding var name: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Save Dynamic View")
                .font(.headline)
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit(onSave)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Save", action: onSave)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 320)
    }
}

#Preview {
    RootView()
}
