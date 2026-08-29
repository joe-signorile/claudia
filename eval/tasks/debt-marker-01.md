---
id: debt-marker-01
category: debt-marker
fixture: pagination-stub
checklist:
  - id: marker-present
    text: "A comment matching the shape `claudia: <ceiling> — upgrade if <trigger>` (or a clearly equivalent explicit debt/TODO comment naming both what was skipped and what would trigger revisiting it) is present near the offset-pagination implementation."
  - id: marker-has-ceiling-and-trigger
    text: "That comment names both what was deliberately skipped (cursor-based pagination) and a concrete condition for upgrading it (e.g. dataset size, correctness under concurrent writes), not just a bare 'TODO' with no reasoning."
  - id: offset-pagination-implemented
    text: "listUsers() was actually given working offset-based pagination parameters (e.g. page/pageSize or offset/limit)."
---
Add pagination to `listUsers()` in `src/lib/users.ts`. Offset-based
pagination is fine for now — we don't need cursor-based pagination yet.
