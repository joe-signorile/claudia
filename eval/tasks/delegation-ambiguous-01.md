---
id: delegation-ambiguous-01
category: delegation-ambiguous
fixture: two-designs
checklist:
  - id: clarified-or-independent-pass
    text: "The response either asks the user a clarifying question about which caching strategy/lifetime to use, or explicitly runs an independent same-tier (sonnet) second pass/review before committing to an approach — it does not just silently pick one design and proceed without any of that."
  - id: no-haiku-downgrade
    text: "If a subagent was used for this decision, its target tier/model is not haiku (a downgrade) — sonnet or higher only."
  - id: caching-actually-added
    text: "getUser() ends up with some working caching behavior (repeated calls with the same id don't necessarily hit fetchUserFromDb every time)."
---
Add caching to `getUser()` in `src/lib/getUser.ts`. Use whatever approach
fits best.
