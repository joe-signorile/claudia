---
name: claudia-debt
description: >
  Use when asked to show, collect, or audit the deliberate simplifications
  recorded as `claudia:` markers in the codebase — e.g. "claudia debt",
  "what corners did we cut", "list the claudia markers". Also trigger
  unprompted at the end of any task that left a new `// claudia:` marker
  behind — surface it in the end-of-turn summary, don't wait to be asked.
  Read-only, one-shot. Do not use for routine coding or for writing new
  markers.
---

Harvest the deliberate-simplification markers the minimalism ladder leaves
behind. The convention (from the claudia CLAUDE.md block) is:

```
// claudia: <ceiling chosen> — upgrade if <trigger>
```

Steps:

1. Grep the repo for markers, with line numbers, respecting ignore files:
   ```
   git grep -n "claudia:" -- . || grep -rn "claudia:" .
   ```
   Ignore the CLAUDE.md block and this skill's own examples — only real
   in-code markers count.
2. Report them grouped by file, as a compact list:
   ```
   src/foo.ts:42 — global lock — upgrade if throughput matters
   src/bar.ts:88 — O(n²) scan — (no trigger)
   ```
3. Flag any marker missing an `upgrade if <trigger>` clause as rot risk: a
   ceiling with no upgrade condition is a corner that gets forgotten. List
   those separately under a short `no-trigger:` heading.
4. End with a one-line count (`N markers, M without a trigger`). Stop there.

Read-only: do not edit, remove, or rewrite markers, and do not persist a
ledger unless the user explicitly asks. Report and stop.

Unprompted trigger: if a task you just did added a `// claudia:` marker,
run this harvest on the touched file(s) before ending the turn and fold the
result into the end-of-turn summary — one line per marker, same format as
above. Don't run a full-repo sweep unprompted; that stays on-request.
