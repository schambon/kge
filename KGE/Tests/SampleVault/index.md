Welcome to the KGE sample vault — a small fake knowledge graph for manually exercising
every feature in the build brief. This is `index.md`, the vault's home page by
convention — opening this folder in KGE (Cmd-Shift-O) should land here automatically.
It has no `id`/`type` frontmatter, so it's an entry point you can open directly but it
can never be a `[[type:id]]` link *target* (open [[proj:mdv]] or [[proj:kge]] instead if
you're testing target resolution).

## What to try

- **The home-page convention itself**: reopen this folder (or relaunch the app with it
  as the last-opened project) and confirm it lands on this file, not a blank pane.

- **Resolved wiki-links, both shorthand and full type**: [[proj:mdv]] uses the `proj`
  shorthand; [[project:kge]] spells the type out — both resolve, since the shorthand
  table maps `proj -> project` and unmapped types fall back to themselves.
- **A label override**: [[person:alice|Alice, who maintains kge]].
- **A duplicate id**, resolving to two files shown as `file1 | file2`: [[note:dup]].
- **An unresolved link** (no file claims this id): [[note:does-not-exist]].
- **An id-less file that still links out**: open `notes/orphan.md` from the sidebar
  directly — notice it has no `type:id` slug shown, and can't be reached via a
  wiki-link (it has no id of its own).
- **Backlinks**: open [[org:acme]] — Alice's note links to it, so it should show up
  under Backlinks.
- **Forward links**: open [[proj:kge]] — it links to several other nodes.
- **GFM rendering** (tables, task lists, code blocks, strikethrough, blockquotes): see
  [[proj:mdv]] and [[note:meeting-jan]].
- **Nested folders / dynamic views**: `projects/archived/old-tool.md` is a `project`
  node nested two levels down — build a Dynamic View (`D`) for type `project` scoped to
  the `projects` folder and confirm all three project nodes show up (subtree, not just
  direct children).
- **Sidebar depth**: expand `projects` → `archived` to confirm the tree walks correctly.
