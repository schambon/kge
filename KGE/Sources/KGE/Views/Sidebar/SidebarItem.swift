import Foundation

/// A row in the sidebar's outline: either part of the real file tree, or part of the
/// virtual "Dynamic Views" folder. Kept as one enum (rather than two separate lists) so
/// `SidebarView` can drive a single `OutlineGroup` over both.
enum SidebarItem: Identifiable {
    case file(FileTreeNode)
    case dynamicViewsRoot(views: [DynamicView])
    case dynamicView(DynamicView)

    var id: String {
        switch self {
        case .file(let node): "file:\(node.url.path)"
        case .dynamicViewsRoot: "dynamicViewsRoot"
        case .dynamicView(let view): "dynamicView:\(view.id)"
        }
    }

    var children: [SidebarItem]? {
        switch self {
        case .file(let node):
            node.children?.map(SidebarItem.file)
        case .dynamicViewsRoot(let views):
            views.map(SidebarItem.dynamicView)
        case .dynamicView:
            nil
        }
    }

    var isDirectory: Bool {
        switch self {
        case .file(let node): node.isDirectory
        case .dynamicViewsRoot: true
        case .dynamicView: false
        }
    }

    var displayLabel: String {
        switch self {
        case .file(let node): node.displayLabel
        case .dynamicViewsRoot: "Dynamic Views"
        case .dynamicView(let view): view.name
        }
    }

    var fileURL: URL? {
        switch self {
        case .file(let node) where !node.isDirectory: node.url
        default: nil
        }
    }

    var dynamicViewValue: DynamicView? {
        if case .dynamicView(let view) = self { view } else { nil }
    }
}
