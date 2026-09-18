import Foundation
import Testing
@testable import KGE

@Suite("NavigationHistory")
struct NavigationHistoryTests {
    private let a = URL(fileURLWithPath: "/vault/a.md")
    private let b = URL(fileURLWithPath: "/vault/b.md")
    private let c = URL(fileURLWithPath: "/vault/c.md")

    @Test("push/back/forward basic stack semantics")
    func pushBackForward() {
        var history = NavigationHistory()
        history.push(a)
        history.push(b)
        history.push(c)

        #expect(history.current == c)
        #expect(history.canGoBack)
        #expect(!history.canGoForward)

        #expect(history.goBack() == b)
        #expect(history.goBack() == a)
        #expect(!history.canGoBack)

        #expect(history.goForward() == b)
        #expect(history.canGoForward)
        #expect(history.goForward() == c)
        #expect(!history.canGoForward)
    }

    @Test("pushing after going back discards the abandoned forward branch")
    func pushAfterBackDiscardsForward() {
        var history = NavigationHistory()
        history.push(a)
        history.push(b)
        _ = history.goBack() // current = a, forward = [b]

        history.push(c) // new navigation from a; b's forward branch is discarded
        #expect(history.current == c)
        #expect(!history.canGoForward)
        #expect(history.goBack() == a)
    }

    @Test("goBack/goForward on empty history return nil without crashing")
    func emptyHistoryIsSafe() {
        var history = NavigationHistory()
        #expect(history.goBack() == nil)
        #expect(history.goForward() == nil)
    }
}
