---
id: kge
type: project
---
# KGE (Knowledge Graph Explorer)

A native macOS rewrite of [[proj:mdv]] with a lightweight knowledge-graph layer.
Built by [[person:bob]], commissioned by [[org:acme]].

An earlier prototype lives in [[proj:old-tool]] — nested under `projects/archived/`, to
exercise sidebar depth and Dynamic View subtree scoping.

See the [[note:meeting-jan]] notes for the kickoff discussion, and
[[note:unresolved-demo]] for an example of an unresolved link.

## Architecture

- WKWebView rendering surface
- swift-markdown (cmark-gfm) parsing
- Yams for frontmatter
- FSEvents for live updates
