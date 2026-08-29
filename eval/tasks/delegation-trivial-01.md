---
id: delegation-trivial-01
category: delegation-trivial
fixture: rename-var
checklist:
  - id: delegated-to-low-tier
    text: "A subagent/Task tool call was used for the mechanical rename work, and its target tier/model is the lowest available tier (haiku), not sonnet or opus."
  - id: delegation-disclosed
    text: "The final response explicitly says the work was delegated and names the tier (e.g. 'delegating to a haiku subagent'), not just silently done."
  - id: rename-correct-and-complete
    text: "Every occurrence of the `usr` variable/parameter name across src/session.ts, src/profile.ts, src/audit.ts, and src/index.ts was renamed to `user`, with no leftover `usr` references and no broken imports."
---
Rename the exported/local `usr` variable to `user` everywhere it's used
in `src/`.
