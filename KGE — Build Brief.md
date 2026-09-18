# KGE — Build Brief

2026-09-18 · @Someone

Spec for KGE (Knowledge Graph Explorer), a native macOS rewrite of [mdv](https://github.com/schambon/mdv), the terminal Markdown pager, as a WKWebView-based GUI app with a lightweight knowledge-graph layer — written to hand to Claude Code.

## Overview & scope

A native macOS rewrite of mdv, focused on markdown exploration with a lightweight knowledge-graph layer over notes.

**In scope:** rendering, link following, a file-tree sidebar, keyboard-first navigation, id-based node resolution, backlinks, and saved dynamic views.

**Out of scope for now:** diff mode and git integration (mdv's `diff`/`git` commands). The original CLI's external preprocessor hook (`-p CMD`) is also dropped — its two jobs, id resolution and backlinks, are built into the app instead.

## Architecture

Window layout: title bar, collapsible sidebar, content pane — kept otherwise plain, no extra chrome.

Menu bar stays basic: Open Folder, New Dynamic View, Save / Delete Dynamic View, Copy, plus the standard macOS defaults.

- Rendering surface: WKWebView, generating HTML on the fly. Chosen over native AttributedString/NSTextView so that lists of nodes, backlinks panels, and dynamic views can reuse the same HTML-generation path.
- Markdown parsing: `swift-markdown` (cmark-gfm). Covers standard CommonMark/GFM — tables, task lists, strikethrough, code blocks.
- Frontmatter parsing: Yams (YAML), reading each file's `id` and `type` fields.
- The `[[type:id]]` link syntax is wiki-link style, not CommonMark — cmark-gfm won't parse it as a link. It needs an internal pre-pass: scan raw text for `[[type:id]]`, resolve against the id index, and substitute a real link. This replaces the old external preprocessor.
- Incremental find-in-page (Cmd-F, /) has no free equivalent in a bare WKWebView — no built-in find UI — so it's built directly against WebKit's find API, the same way mdv's own literal search works today.
- Keyboard shortcuts are captured above the WebView (in the containing view/window), not left to WKWebView's own key handling — WebKit reserves Tab (cycles the page's own links) and arrow keys (scrolling) by default. Single letter keys (j, k, b, l, d, s) have no WebKit-reserved meaning and are safe to bind directly.

## Sidebar & file navigation

- The sidebar shows a file tree of the project root, built with SwiftUI's `List(_, children:)` in `.sidebar` style — the standard hierarchical-list pattern.
- One caveat worth checking once built: some implementations of this pattern eagerly evaluate a folder's children before it's expanded, rather than lazily on demand. Unlikely to matter for a personal notes folder; worth confirming if the root could ever be very large.
- Markdown files without `id`/`type` frontmatter still appear in the tree (it's filesystem-driven) and can still be opened directly, and can still contain outgoing `[[type:id]]` links to other files — but having no id themselves, they can never be a link *target*.

## Knowledge graph

- Each node is a markdown file with `id` and `type` in its frontmatter (e.g. `type: project`, `id: mdv`).
- Links use `[[type:id]]` (e.g. `[[proj:mdv]]`) — double brackets, distinct from ordinary `[text](url)` links. `proj` is a shorthand mapped to the full type value (`project`); this mapping needs a small lookup table.
- Edges are untyped — the graph only distinguishes node type, not relationship type. A node's text can link freely to any other, e.g. "this person belongs to \[\[org:whatever\]\]".
- Backlinks ("what links here") come from a full-corpus scan of outgoing `[[type:id]]` references, inverted into a reverse map — a separate, larger pass than id lookup, since it has to read every file's body, not just its frontmatter.
- Display: a node's label is its filename (minus `.md`), with its `type:id` slug also surfaced. Resolved links and backlinks display the same way — filename, not the raw slug. A display-text override (`[[type:id|label]]`) is supported but not currently used.
- Duplicate ids: the index tolerates two files claiming the same `(type, id)` and surfaces the clash rather than picking one silently — a link to a duplicated id resolves to both, shown as `file1 | file2`.

## Indexing & live updates

- The id index and backlink graph are built asynchronously in memory at launch (background thread), not persisted to disk between launches — rebuilding is cheap at this scale (300 to under 10,000 nodes) and avoids a cache-invalidation problem that only pays off at far larger corpora.
- Live refresh uses FSEvents (the CoreServices recursive directory-watching API), not `DispatchSource`/kqueue-based per-path watching. Kqueue needs one open watch per directory and has a documented failure mode at scale (silently drops events past a few thousand watched directories); FSEvents watches the whole subtree from a single root regardless of file or folder count.
- One shared primitive covers all three refresh paths — initial build, FSEvents-driven incremental update, and a manual reindex command: "(re)parse this one file, splice its id/type and outgoing links into the index." It needs a remove path too, for files that are deleted or renamed, not just add/update.

## Dynamic views

- A dynamic view is a saved filter: e.g. all nodes of type T under folder F (subtree, not just direct children).
- The `D` command opens a view: pick a type (picker/typeahead) and a folder — defaults to the current folder, or choose elsewhere in the project tree — and it renders immediately. Save it from the title bar's save icon or Cmd-S, which prompts for a name; saved views then appear under the sidebar's "Dynamic Views" folder and open via Cmd-O like any other quick-open entry. Once saved, the title bar's save icon becomes a trash icon, for deleting the view.
- Type comes from frontmatter, path from the same directory walk that builds the sidebar tree and id index — no new mechanism needed.
- Saved views are stored strictly locally (Application Support), keyed to the project root's path (or a security-scoped bookmark). They don't sync across machines — a view saved on one Mac won't appear on another, even against the same vault.
- Dynamic views are not addressable or linkable — no id, can't appear in `[[type:id]]` links. They're reachable by name via quick-open (Cmd-O) and listed under a virtual "Dynamic Views" folder in the sidebar.

## Keyboard shortcuts

| Key | Action | Context |
| --- | --- | --- |
| j / k | Move to next/previous link; Enter opens the focused link; scroll to backlinks at the bottom | Content pane |
| S | Switch focus between sidebar and content pane | Global |
| ↑ / ↓ | Move selection in the file tree | Sidebar |
| ↑ / ↓ | Scroll content | Content pane |
| Cmd-O | Quick-open any node, with typeahead | Global |
| B | Quick backlinks pane (what links here) | Content pane |
| L | Quick forward-links pane (what this node links to) | Content pane |
| D | Build a dynamic view (type T under folder F) | Global |
| Cmd-F, / | Incremental find-in-page | Content pane |
| Cmd-F, / | Find in sidebar | Sidebar |
| Cmd-← / Cmd-→ (also `<` / `>`) | Back / forward (also a Finder-style title-bar control) | Content pane |
| Cmd-Shift-F | Reveal current node or folder in Finder | Global |
