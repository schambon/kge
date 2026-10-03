---
id: project:mdv
type: project
---
# mdv

`mdv` is the terminal Markdown pager this app is a native rewrite of. Maintained by
[[person:alice|Alice, who maintains kge]], with help from [[person:bob]].

Its spiritual successor is [[project:kge]] — this link spells the type out in full,
while other links in this vault use the `proj` shorthand; both should resolve to the
same node.

## Commands

| Command | Description |
| --- | --- |
| `mdv <file>` | Open a file in the pager |
| `mdv diff <a> <b>` | Diff mode (dropped in the KGE rewrite) |
| `mdv -p <cmd>` | External preprocessor hook (also dropped) |

## Remaining polish

- [x] CommonMark/GFM rendering
- [x] Wiki-link resolution
- [ ] ~~External preprocessor hook~~ — deliberately out of scope for KGE
- [ ] Syntax highlighting in code blocks

## Example usage

```bash
mdv README.md
mdv -p ./resolve-links.sh notes/*.md
```

> Note: diff mode and the preprocessor hook are explicitly out of scope for KGE — their
> two jobs (id resolution, backlinks) are built into the app instead.
