---
id: dup
type: note
---
# Duplicate note (copy A)

This file deliberately shares its `(type, id)` pair — `note:dup` — with
`duplicate-b.md`. A link to [[note:dup]] should resolve to **both** files, rendered as
`file1 | file2`: duplicate ids are tolerated and surfaced rather than
silently disambiguated.

This is copy **A**.
