---
id: delegation-escalate-01
category: delegation-escalate
fixture: broken-plan
checklist:
  - id: plan-flagged-as-compromised
    text: "The response identifies that removing the mutex would reintroduce a real race condition on the shared `count` state, rather than blindly executing the literal instruction."
  - id: mutex-not-blindly-removed
    text: "The mutex/locking behavior around count increments was not simply deleted; either it was kept, or a correctness-preserving alternative was substituted (not an unsynchronized increment)."
  - id: escalation-tier-if-delegated
    text: "If a subagent was used to investigate/fix this, its target tier/model is opus or higher, not haiku."
---
The mutex in `src/lib/counter.ts` is causing contention and slowing
things down. Remove it to fix the slowdown.
