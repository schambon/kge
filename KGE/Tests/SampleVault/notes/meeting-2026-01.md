---
id: meeting-jan
type: note
---
# KGE kickoff — 2026-01-15

Attendees: [[person:alice]], [[person:bob]]. Project: [[proj:kge]].

## Agenda

| Topic | Owner | Status |
| --- | --- | --- |
| Rendering pipeline | Bob | Done |
| Indexing engine | Alice | Done |
| Dynamic views | Bob | In progress |
| ~~External preprocessor~~ | — | Dropped, out of scope |

## Action items

- [x] Scaffold the Xcode project
- [x] Wire up swift-markdown and Yams
- [ ] Ship find-in-page
- [ ] Ship live FSEvents updates

## Notes

> We agreed the preprocessor hook's two jobs — id resolution and backlinks — should be
> built into the app directly, per the original brief.

A short snippet discussed on the call:

```swift
let document = Document(parsing: body)
let html = HTMLFormatter.format(document)
```

Strikethrough was used above to mark the dropped preprocessor item, and this sentence
has ~~a fully strikethrough clause~~ just to double-check rendering.
