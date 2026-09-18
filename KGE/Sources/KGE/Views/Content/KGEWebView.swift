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
/// events above WebKit's own handling, per the brief: WebKit reserves Tab and arrow
/// keys, but single letters (j, k, b, l, d, s) are safe to bind directly.
final class KGEWebView: WKWebView {
    weak var keyHandler: WebKeyHandling?

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

    func makeNSView(context: Context) -> KGEWebView {
        let webView = KGEWebView()
        webView.navigationDelegate = context.coordinator
        webView.keyHandler = context.coordinator
        context.coordinator.webView = webView
        onWebViewCreated(webView)
        return webView
    }

    func updateNSView(_ webView: KGEWebView, context: Context) {
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
    final class Coordinator: NSObject, WKNavigationDelegate, WebKeyHandling {
        weak var webView: WKWebView?
        var onOpenNode: (URL) -> Void = { _ in }
        var onOpenBacklinks: () -> Void = {}
        var onOpenForwardLinks: () -> Void = {}
        var lastLoadedHTML: String?

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            if url.scheme == "kge", url.host == "open" {
                decisionHandler(.cancel)
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let path = components.queryItems?.first(where: { $0.name == "path" })?.value {
                    onOpenNode(URL(fileURLWithPath: path))
                }
                return
            }

            if navigationAction.navigationType == .linkActivated,
               let scheme = url.scheme, scheme == "http" || scheme == "https" {
                decisionHandler(.cancel)
                NSWorkspace.shared.open(url)
                return
            }

            decisionHandler(.allow)
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
