---
id: delegation-none-01
category: delegation-none-needed
fixture: single-line-fix
checklist:
  - id: no-subagent-fanout
    text: "No Agent/Task subagent tool call was used for this fix — it's a genuinely trivial one-line, one-file typo, and delegating it would be pure overhead."
  - id: fix-correct
    text: "`retrun` in src/util.ts was corrected to `return`, and nothing else was rewritten unnecessarily."
---
Typo: `retrun` should be `return` in `src/util.ts`.
