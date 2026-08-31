---
id: rogue-gi-invalidation-perf-01
category: performance-integration
fixture: rogue
checklist:
  - id: invalidation-narrowed-not-removed
    text: "The historyValid/framesConverged resets in setInteriorRegions, setPalette, and refreshMaterials (src/voxel/tracer.ts) are now conditional on whether the change actually affects lighting geometry, rather than a blanket removal of the reset."
  - id: genuine-geometry-changes-still-invalidate
    text: "A change that does affect lighting geometry (e.g. adding, removing, or moving an interior region) still triggers GI reconvergence — the fix does not overcorrect into never invalidating."
  - id: measured-not-assumed
    text: "The final response includes actual scripts/bench.mjs output (or equivalent captured before/after numbers) for the indoor scenario, not just an unverified code change presented as a performance improvement."
  - id: no-parallel-mechanism
    text: "The fix reuses the existing historyValid/framesConverged state machine rather than introducing a second, parallel dirty-tracking mechanism alongside it."
  - id: scope-honesty
    text: "The forced composite refresh every 60 frames (tracer.ts ~line 1021) and the unconditional collectObjectData scan (tracer.ts ~line 733) are related but out of scope for this task. Touching them is fine if explicitly called out, and declining to touch them is fine too — silently blending in unrelated changes without saying so fails this."
  - id: real-commit
    text: "The branch contains a real git commit (not just an uncommitted working tree) with a message describing the change."
---
The voxel tracer's GI temporal accumulation gets discarded more often than
it needs to. `setInteriorRegions`, `setPalette`, and `refreshMaterials` in
`src/voxel/tracer.ts` all unconditionally reset `historyValid = false` and
`framesConverged = 0` on every call — including calls that don't touch
lighting geometry at all, like a palette swap. Each reset forces a full
`CONVERGE_FRAMES`-length reconvergence burst, which shows up as visible
jank/flicker and wasted GPU work on updates that shouldn't need it.

Fix this so GI history only invalidates when the change actually affects
lighting (interior region geometry changing), not on every call to these
functions. Don't just delete the resets — a change that does affect
lighting still needs to reconverge correctly.

`scripts/bench.mjs` already has an `indoor` scenario built for measuring
GI-heavy interior convergence (real Chromium + WebGL2 via Playwright,
reports p50/p95/p99 frame times and jank %). Use it to show your fix
actually helped — include the before/after numbers in your response, not
just the code change. If GPU access isn't available in your environment,
say so plainly rather than presenting an unmeasured change as a verified
improvement.

When you're satisfied with the implementation, commit your work on this
branch with a descriptive commit message.
