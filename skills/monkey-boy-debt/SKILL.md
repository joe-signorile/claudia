---
name: monkey-boy-debt
description: >
  Use when asked to show, collect, or audit the deliberate simplifications
  recorded as `monkey-boy:` markers in the codebase — e.g. "monkey-boy debt",
  "what corners did we cut", "list the monkey-boy markers". Read-only, one-shot.
  Do not use for routine coding or for writing new markers.
---

Harvest the deliberate-simplification markers the minimalism ladder leaves
behind. The convention (from the monkey-boy CLAUDE.md block) is:

```
// monkey-boy: <ceiling chosen> — upgrade if <trigger>
```

Steps:

1. Grep the repo for markers, with line numbers, respecting ignore files:
   ```
   git grep -n "monkey-boy:" -- . || grep -rn "monkey-boy:" .
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
