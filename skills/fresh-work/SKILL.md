---
name: fresh-work
description: >
  Use when starting genuinely new work: a new feature, a new component/module,
  a new script, "build me a...", "add support for...", "create a...", or any
  request with no existing partial implementation to iterate on. Do not use
  for bug fixes, small edits, follow-ups, or requests continuing work already
  in progress.
---

Before writing any code:

1. Confirm scope in a compact key:value block, not prose:
   ```
   goal: <what>
   constraints: <what must hold>
   files: <relevant existing files, if any>
   ```
2. Ask clarifying questions if genuinely ambiguous — don't silently guess on
   anything that would materially change the design.
3. If Claude Code's plan mode is already active, defer to it — don't
   duplicate the ceremony. This skill exists for fresh work requested outside
   of an explicit plan-mode session.
4. Once scope is confirmed, execute. Don't re-restate the plan or narrate
   each step — that's the monkey-boy anti-ceremony rule, and it still applies
   here.

This supplements, not replaces, the monkey-boy output style's voice and
minimalism ladder — keep using both.
