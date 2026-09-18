import SwiftUI
import WebKit

/// The find-in-page overlay. A bare `WKWebView` has no find UI, so this is built
/// directly against WebKit's find API (`WKWebView.find`) rather than any browser chrome.
struct FindBarView: View {
    @Binding var query: String
    let onNext: () -> Void
    let onPrevious: () -> Void
    let onClose: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            TextField("Find", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit(onNext)
                .frame(width: 220)
            Button(action: onPrevious) {
                Image(systemName: "chevron.up")
            }
            .disabled(query.isEmpty)
            Button(action: onNext) {
                Image(systemName: "chevron.down")
            }
            .disabled(query.isEmpty)
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 4)
        .padding(8)
        .onAppear { isFocused = true }
        .onExitCommand(perform: onClose)
    }
}

/// Drives `WKWebView.find` for a `FindBarView`, holding the live web view reference
/// captured via `KGEWebViewRepresentable.onWebViewCreated`.
@MainActor
final class FindController: ObservableObject {
    @Published var isVisible = false
    @Published var query = ""

    weak var webView: WKWebView?

    func open() {
        isVisible = true
    }

    func close() {
        isVisible = false
        guard let webView else { return }
        Task {
            _ = try? await webView.find("", configuration: WKFindConfiguration())
        }
    }

    func findNext() {
        find(backwards: false)
    }

    func findPrevious() {
        find(backwards: true)
    }

    private func find(backwards: Bool) {
        guard !query.isEmpty, let webView else { return }
        let configuration = WKFindConfiguration()
        configuration.backwards = backwards
        configuration.caseSensitive = false
        configuration.wraps = true
        let text = query
        Task {
            _ = try? await webView.find(text, configuration: configuration)
        }
    }
}
