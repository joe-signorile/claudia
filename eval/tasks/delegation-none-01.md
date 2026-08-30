---
id: delegation-none-01
category: delegation-none-needed
fixture: single-line-fix
trials: 1
checklist:
  - id: no-subagent-fanout
    text: "No Agent/Task subagent tool call was used for this fix — it's a genuinely trivial one-line, one-file typo, and delegating it would be pure overhead."
  - id: fix-correct
    text: "`retrun` in src/util.ts was corrected to `return`, and nothing else was rewritten unnecessarily."
  - id: minimal-diff-scope
    text: "The diff touches only src/util.ts and changes only the misspelled `retrun` keyword — no reformatting or other edits elsewhere in the file."
  - id: response-is-terse
    text: "The final response is a brief confirmation (a sentence or two), not a restated plan or lengthy explanation, for what is a one-line typo fix."
---
Typo: `retrun` should be `return` in `src/util.ts`.
