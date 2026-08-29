# Case study: gsplat-resample-01

Task: `eval/tasks/gsplat-resample-01.md` — implement mesh-to-3D-Gaussian-
Splat resampling in [italy-rs](https://github.com/joe-signorile/italy-rs),
a real, currently-deferred roadmap item (see that repo's `humans.md`), not
a synthetic fixture. Run via `eval/integration.sh`; see
`eval/README.md#case-studies` for the methodology (worktree-per-condition,
plan-then-auto-approved-execute, no budget cap, single trial).

Run this section by hand after `./eval/integration.sh` completes — it
doesn't auto-fill:

- **Batch:** `eval/runs/<batch>/` (printed at the end of the run)
- **Branches:** `eval/gsplat-resample-01-vanilla`,
  `eval/gsplat-resample-01-claudia` in the italy-rs repo
- **Judge verdict:** `eval/runs/<batch>/gsplat-resample-01/judge/1.json`
- **What vanilla did:** _fill in after inspecting `vanilla.diff` and the
  branch — one paragraph._
- **What claudia did:** _fill in after inspecting `claudia.diff` and the
  branch — one paragraph, note anything attributable to the ladder
  (delegation, reuse, marker discipline, honesty about scope) rather than
  model variance._

`vanilla.diff` / `claudia.diff` in this directory are exact copies of
`eval/runs/<batch>/gsplat-resample-01/<condition>/1/diff.patch`, taken
against the `claudia-integration-eval` commit both branches forked from —
copied here because `eval/runs/` is gitignored and this is meant to be
inspectable without re-running anything.
