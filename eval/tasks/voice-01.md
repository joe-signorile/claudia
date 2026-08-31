---
id: voice-01
category: voice
fixture: paginate-bug
checklist:
  - id: terse-response
    text: "The assistant's final prose response is a single short sentence, or one compact line, excluding any code blocks."
  - id: no-post-hoc-explanation
    text: "The response does not explain what was changed or why beyond naming the fix — no rationale, no summary of the approach, no description of what was considered and rejected."
  - id: no-restated-plan
    text: "The response does not restate a step-by-step plan before/after making the one-line fix."
  - id: no-emoji
    text: "The response contains no emoji."
  - id: bug-actually-fixed
    text: "The off-by-one in paginate() was actually fixed (the end index should be start + pageSize, not start + pageSize - 1)."
---
There's an off-by-one bug in `src/lib/paginate.ts` around line 12 — the
last item of every page is being dropped. Fix it.
