import SwiftUI

/// Which pane currently owns keyboard focus: the sidebar (native `List` arrow-key
/// selection) or the content pane (WKWebView scrolling / j-k link navigation). `S`
/// toggles this and also moves AppKit's first responder to match, so subsequent native
/// key handling goes to the right place.
enum FocusZone {
    case sidebar
    case content
}

@MainActor
final class AppState: ObservableObject {
    @Published var focusZone: FocusZone = .content
}
