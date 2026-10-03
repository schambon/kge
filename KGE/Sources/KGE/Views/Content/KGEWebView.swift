import SwiftUI
import WebKit

/// Handles key events forwarded from the web view before falling back to WebKit's own
/// handling (arrow-key scrolling, Tab link-cycling, etc.).
@MainActor
protocol WebKeyHandling: AnyObject {
    /// Returns `true` if the event was consumed and should not reach WebKit.
    func handle(_ event: NSEvent) -> Bool
}

/// A `WKWebView` subclass that gives the containing app a chance to intercept key
/// events above WebKit's own handling: WebKit reserves Tab and arrow
/// keys, but single letters (j, k, b, l, d, s) are safe to bind directly.
final class KGEWebView: WKWebView {
    weak var keyHandler: WebKeyHandling?
    /// Title for an extra "View Source"/"View Rendered" context-menu item; nil hides it.
    var sourceToggleTitle: String?
    var onToggleSource: () -> Void = {}

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        super.willOpenMenu(menu, with: event)
        guard let title = sourceToggleTitle else { return }
        let item = NSMenuItem(title: title, action: #selector(toggleSource), keyEquivalent: "")
        item.target = self
        menu.insertItem(item, at: 0)
        menu.insertItem(.separator(), at: 1)
    }

    @objc private func toggleSource() { onToggleSource() }

    override func keyDown(with event: NSEvent) {
        if let handler = keyHandler, handler.handle(event) {
            return
        }
        super.keyDown(with: event)
    }
}

/// SwiftUI wrapper around `KGEWebView`. Loads `html` (with `baseURL` so relative
/// resources such as `<img src="...">` in notes resolve against the source file's
/// directory) whenever it changes.
struct KGEWebViewRepresentable: NSViewRepresentable {
    var html: String
    var baseURL: URL?
    var onOpenNode: (URL) -> Void = { _ in }
    var onOpenBacklinks: () -> Void = {}
    var onOpenForwardLinks: () -> Void = {}
    var onWebViewCreated: (WKWebView) -> Void = { _ in }
    /// Nil when the current page isn't a file (e.g. a dynamic view): no menu item.
    var sourceToggleTitle: String?
    var onToggleSource: () -> Void = {}

    func makeNSView(context: Context) -> KGEWebView {
        let webView = KGEWebView()
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.keyHandler = context.coordinator
        context.coordinator.webView = webView
        onWebViewCreated(webView)
        return webView
    }

    func updateNSView(_ webView: KGEWebView, context: Context) {
        webView.sourceToggleTitle = sourceToggleTitle
        webView.onToggleSource = onToggleSource
        context.coordinator.onOpenNode = onOpenNode
        context.coordinator.onOpenBacklinks = onOpenBacklinks
        context.coordinator.onOpenForwardLinks = onOpenForwardLinks
        if context.coordinator.lastLoadedHTML != html {
            context.coordinator.lastLoadedHTML = html
            webView.loadHTMLString(html, baseURL: baseURL)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WebKeyHandling {
        weak var webView: WKWebView?
        var onOpenNode: (URL) -> Void = { _ in }
        var onOpenBacklinks: () -> Void = {}
        var onOpenForwardLinks: () -> Void = {}
        var lastLoadedHTML: String?

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            if handleAppLevelNavigation(to: url, navigationType: navigationAction.navigationType) {
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        /// Handles a modified click (Cmd-click, middle-click, "Open Link in New Window")
        /// on an in-page link. WebKit routes these through `window.open()`-style handling
        /// rather than `decidePolicyFor`, so without a `WKUIDelegate` it falls back to
        /// asking the system to open the URL directly — fatal for the `kge://` scheme,
        /// which has no registered app handler. Intercept the same way and never actually
        /// create a new web view.
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let url = navigationAction.request.url {
                _ = handleAppLevelNavigation(to: url, navigationType: navigationAction.navigationType)
            }
            return nil
        }

        /// Shared interception for `kge://open` node links and external `http(s)` links,
        /// used by both the normal navigation path and the new-window path. Returns
        /// `true` if the navigation was handled in-app and should not proceed as-is.
        private func handleAppLevelNavigation(to url: URL, navigationType: WKNavigationType) -> Bool {
            if url.scheme == "kge", url.host == "open" {
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let path = components.queryItems?.first(where: { $0.name == "path" })?.value {
                    onOpenNode(URL(fileURLWithPath: path))
                }
                return true
            }

            if navigationType == .linkActivated,
               let scheme = url.scheme, scheme == "http" || scheme == "https" {
                NSWorkspace.shared.open(url)
                return true
            }

            return false
        }

        /// Handles `j`/`k`/`b`/`l`/Enter — the shortcuts that only make sense when the
        /// web view itself is key. Checked only when no Command modifier is held; arrow
        /// keys are deliberately left unhandled so `super.keyDown` reproduces WebKit's
        /// native scroll behavior.
        func handle(_ event: NSEvent) -> Bool {
            guard !event.modifierFlags.contains(.command) else { return false }

            switch event.charactersIgnoringModifiers {
            case "j":
                webView?.evaluateJavaScript("kgeFocusNextLink();")
                return true
            case "k":
                webView?.evaluateJavaScript("kgeFocusPrevLink();")
                return true
            case "b":
                onOpenBacklinks()
                return true
            case "l":
                onOpenForwardLinks()
                return true
            default:
                break
            }

            // Enter activates the currently link-focused element (distinct from
            // Command modifiers, already excluded above).
            if event.keyCode == 36 /* Return */ {
                webView?.evaluateJavaScript("kgeActivateFocusedLink();")
                return true
            }

            return false
        }
    }
}
