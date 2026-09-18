import SwiftUI

/// The native SwiftUI list shown by the `B` (backlinks) / `L` (forward-links) keyboard
/// shortcuts — deliberately a plain `List`, not a second WebView, since this is a quick
/// glance/jump panel rather than rendered prose.
struct LinksPopoverView: View {
    let title: String
    let nodes: [DisplayNode]
    let onSelect: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.headline)
                .padding([.horizontal, .top])
                .padding(.bottom, 4)
            if nodes.isEmpty {
                Text("None.")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                List(nodes, id: \.url) { node in
                    Button {
                        onSelect(node.url)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(node.label)
                            if let subtitle = node.subtitle {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(minWidth: 260, minHeight: 200)
    }
}
