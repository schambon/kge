# KGE — Knowledge Graph Explorer

KGE is a native macOS app for reading a folder of Markdown notes as a knowledge graph. It is a GUI rewrite of [mdv](https://github.com/schambon/mdv), a terminal Markdown pager, with id-based links, backlinks, saved views and keyboard-first navigation built in.

Open a folder and KGE renders its Markdown files, resolves links between notes by id, and shows what links to what. It is a reader and explorer: it doesn't edit your notes.

## Features

- **Markdown rendering** (CommonMark/GFM: tables, task lists, strikethrough, code blocks) in a single WKWebView.
- **File-tree sidebar** of the opened folder. Every Markdown file appears, whether or not it has frontmatter.
- **Wiki-links by id.** Notes declare an `id` and `type` in YAML frontmatter, and other notes link to them with `[[type:id]]`.
- **Backlinks and forward links**, shown in the page and in quick popovers.
- **Dynamic views**: saved filters such as "all nodes of type `person` under `orgs/`".
- **Quick open** with typeahead across nodes and dynamic views.
- **Find in page** and find in the sidebar.
- **Back/forward history**, including trackpad swipe.
- **Live updates**: edit your notes in any editor and KGE re-indexes them as they change (FSEvents).

## Notes and links

A file is a *node* if its frontmatter has both `id` and `type`:

```markdown
---
id: mdv
type: project
---
# mdv

Maintained by [[person:alice|Alice]].
```

- `[[type:id]]` links to a node; `[[type:id|label]]` overrides the displayed text.
- Type prefixes can be shorthands: `[[proj:mdv]]` resolves to `project`. Unknown prefixes are treated as the full type name.
- Links are untyped; only nodes have types.
- Files without `id`/`type` still show in the tree, can be opened, and can link out, but can't be link targets.
- If two files claim the same `(type, id)`, the clash is shown rather than hidden: a link to it resolves to both, displayed as `file1 | file2`.
- Unresolved links are shown as such.
- Nodes are labelled by filename (minus `.md`), with the `type:id` slug alongside.
- A folder's home page is `index.md` directly under its root (case-insensitive). It opens automatically with the folder.

## Dynamic views

A dynamic view is a saved filter: all nodes of type *T* anywhere under folder *F*. Press `D` to build one, then save it with Cmd-S. Saved views appear in a virtual "Dynamic Views" folder in the sidebar and in quick open.

Dynamic views are not nodes and can't be link targets. They are stored locally in Application Support, keyed by the project folder, and are not synced between machines.

## Keyboard

| Key | Action |
| --- | --- |
| `j` / `k` | Next / previous link in the content pane; Enter opens it |
| `S` | Switch focus between sidebar and content |
| `B` | Backlinks of the current node |
| `L` | Forward links of the current node |
| `D` | New dynamic view |
| Cmd-O | Quick open |
| Cmd-F or `/` | Find (in the content pane or sidebar, depending on focus) |
| Cmd-← / Cmd-→ or `<` / `>` | Back / forward |
| Cmd-Shift-O | Open folder |
| Cmd-S | Save the current dynamic view |
| Cmd-Shift-F | Reveal in Finder |

## Indexing

The index is built in memory in the background at launch and never persisted. It is aimed at collections of roughly 300–10,000 notes. Two passes are kept separate: a cheap frontmatter pass for ids and types, and a full-body scan for outgoing links, which is inverted into the backlink map. Initial build, file-system updates and manual reindex all go through the same "re-parse this file and splice it into the index" step.

## Building

Requires macOS 14+ and Xcode with Swift 6. Dependencies are [swift-markdown](https://github.com/apple/swift-markdown) and [Yams](https://github.com/jpsim/Yams), fetched by Swift Package Manager.

```bash
cd KGE
xcodebuild -project KGE.xcodeproj -scheme KGE -destination 'platform=macOS' build
xcodebuild -project KGE.xcodeproj -scheme KGE -destination 'platform=macOS' test
```

Or open `KGE/KGE.xcodeproj` in Xcode and press Cmd-R / Cmd-U. The app is sandboxed; you may need to set your own signing team in the target's settings.

The Xcode project is generated from `KGE/project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`). After adding or removing source files or changing build settings, edit `project.yml` and run `xcodegen generate` in `KGE/` rather than editing the `.xcodeproj` by hand.

`KGE/Tests/SampleVault` is a small fake vault (people, orgs, projects, duplicate ids, unresolved links) used by the tests. It is also handy for trying the app: open it as a folder.

## Out of scope

Diff mode, git integration, and mdv's external preprocessor hook (`-p CMD`); id resolution and backlinks are built in instead.

## Documentation

[`CLAUDE.md`](CLAUDE.md) holds architecture notes and guidance for AI coding assistants.

## License

MIT — see [`LICENSE`](LICENSE).
