# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current state

All ten build milestones from the implementation plan are done: indexing (`GraphIndex`, id/backlink index, FSEvents live updates), the wiki-link/HTML rendering pipeline, the WKWebView content pane with click-through navigation, the real sidebar tree, keyboard shortcuts (S/j/k/B/L/D, Cmd-O/F/S, history), find-in-page, quick-open, and dynamic views (builder, save/delete, sidebar + quick-open integration). 22 unit tests cover the indexer, renderer, navigation history, dynamic-view filtering/persistence, and a real FSEvents round-trip. Read `KGE — Build Brief.md` before changing behavior described there — it remains authoritative over assumptions made here.

Follow-up work not yet done: app icon/branding, onboarding/empty-state polish beyond the basic "no folder open" placeholder, and the deeper manual keyboard/GUI walkthrough noted in the plan (headless CI can't drive the actual WKWebView key handling or SwiftUI `List` lazy-loading behavior — those were verified via unit-level proxies; a human pass in Xcode is still worthwhile before shipping).

The project is generated with **XcodeGen** from `KGE/project.yml`, not hand-edited as XML. After adding/removing/moving source files, or changing targets, dependencies, or build settings, edit `project.yml` and regenerate — do not hand-edit `KGE.xcodeproj/project.pbxproj`:

```bash
cd KGE && xcodegen generate
```

(`xcodegen` is installed via Homebrew: `brew install xcodegen` if missing.) `KGE.xcodeproj` itself **is committed** (XcodeGen output is deterministic and opens directly in Xcode); only `xcuserdata/`, `DerivedData/`, and `.build/` are gitignored.

## Build & test

Open `KGE/KGE.xcodeproj` in Xcode and use it throughout (per user preference) — Cmd-R to run, Cmd-U to test. From the command line:

```bash
cd KGE
xcodebuild -project KGE.xcodeproj -scheme KGE -destination 'platform=macOS' build
xcodebuild -project KGE.xcodeproj -scheme KGE -destination 'platform=macOS' test
```

To run a single test (Swift Testing, not XCTest — tests use `@Test`/`@Suite` from the `Testing` framework):

```bash
xcodebuild -project KGE.xcodeproj -scheme KGE -destination 'platform=macOS' test -only-testing:KGETests/KGETests/sanity
```

First build after cloning or after touching `project.yml`'s `packages:` section needs package resolution:

```bash
xcodebuild -resolvePackageDependencies -project KGE.xcodeproj
```

## What KGE is

A native macOS rewrite of [mdv](https://github.com/schambon/mdv) (a terminal Markdown pager) as a WKWebView-based GUI app with a knowledge-graph layer over a folder of Markdown notes: id-based node resolution, backlinks, saved dynamic views, keyboard-first navigation.

Explicitly out of scope: diff mode, git integration, and mdv's external preprocessor hook (`-p CMD`) — the preprocessor's two jobs (id resolution, backlinks) are built into the app instead.

## Planned stack

- Swift / SwiftUI shell, AppKit where SwiftUI falls short (key handling, find-in-page).
- **swift-markdown** (cmark-gfm) for CommonMark/GFM parsing.
- **Yams** for YAML frontmatter (`id`, `type` fields).
- **WKWebView** as the single rendering surface — HTML generated on the fly.
- **FSEvents** (CoreServices) for live file watching.

## Architecture constraints that matter

These are decisions already made in the brief; changing one has knock-on effects.

- **One HTML generation path.** Node pages, backlink panels, forward-link panels, and dynamic views all render as generated HTML into the same WKWebView. That's why WKWebView was chosen over NSTextView/AttributedString — don't split rendering across two surfaces.
- **`[[type:id]]` is not CommonMark.** cmark-gfm will not parse wiki-links. They require an internal pre-pass over raw text *before* markdown parsing: scan for `[[type:id]]` (and the supported-but-unused `[[type:id|label]]`), resolve against the id index, substitute a real link. Type prefixes are shorthands (`proj` → `project`) resolved through a lookup table.
- **Keyboard handling lives above the WebView**, in the containing view/window. WebKit reserves Tab (cycles page links) and arrow keys (scrolling). Single letters (j, k, b, l, d, s) are unreserved and safe to bind directly.
- **Find-in-page is built on WebKit's find API** directly — a bare WKWebView has no find UI.
- **One shared reindex primitive** serves all three refresh paths (initial build, FSEvents incremental update, manual reindex): "(re)parse this one file, splice its id/type and outgoing links into the index." It needs a remove path for deleted/renamed files, not just add/update.
- **FSEvents, not kqueue/DispatchSource.** Kqueue needs one watch per directory and silently drops events past a few thousand directories.
- **Index is in-memory only**, built asynchronously at launch, never persisted. Target corpus is 300–10,000 nodes; caching only pays off far above that and costs an invalidation problem.

## Graph model

- A node is a Markdown file with both `id` and `type` in frontmatter. Files lacking them still appear in the tree and can be opened and can contain outgoing links — they just can't be link *targets*.
- Edges are untyped; only node types are distinguished.
- Backlinks come from a full-corpus body scan inverted into a reverse map — a heavier pass than the frontmatter-only id index. Keep the two passes distinct.
- Duplicate `(type, id)` pairs are tolerated and surfaced, not silently disambiguated: a link to a duplicated id resolves to both, displayed `file1 | file2`.
- Display label is always the filename minus `.md` (with the `type:id` slug surfaced alongside) — never the raw slug alone.

## Dynamic views

A saved filter: all nodes of type T under folder F (subtree, not direct children). Not addressable — no id, can never be a `[[type:id]]` target. Reachable via Cmd-O quick-open and a virtual "Dynamic Views" sidebar folder. Persisted strictly locally in Application Support, keyed to the project root path (or a security-scoped bookmark); deliberately does not sync across machines.

## Keyboard map

See the table at the end of the brief — it is the source of truth. Summary: `j`/`k` link navigation, `S` focus switch, `B`/`L` backlink/forward-link panes, `D` dynamic view, Cmd-O quick-open, Cmd-F or `/` find, Cmd-←/→ (or `<`/`>`) history, Cmd-Shift-F reveal in Finder.

## Known open question

SwiftUI's `List(_, children:)` sidebar pattern may eagerly evaluate a folder's children before expansion in some implementations. Unlikely to matter at personal-notes scale; verify once the tree is built if the root could ever be large.
