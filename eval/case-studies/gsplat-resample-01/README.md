# Case study: gsplat-resample-01

Task: `eval/tasks/gsplat-resample-01.md` — implement mesh-to-3D-Gaussian-
Splat resampling in [italy-rs](https://github.com/joe-signorile/italy-rs),
a real, currently-deferred roadmap item (see that repo's `humans.md`), not
a synthetic fixture. Run via `eval/integration.sh`; see
`eval/README.md#case-studies` for the methodology (worktree-per-condition,
plan-then-auto-approved-execute, no budget cap, single trial per tier).

Run twice, once per model/effort tier: `EVAL_MODEL=sonnet EVAL_EFFORT=medium`
(the default) and `EVAL_MODEL=opus EVAL_EFFORT=high`. Each run writes its
diffs into a sibling directory named for its tier — this file is the
task-level index, not per-tier output:

- `../gsplat-resample-01--sonnet-medium/{vanilla,claudia}.diff`
- `../gsplat-resample-01--opus-high/{vanilla,claudia}.diff`

For each tier directory above (filled in by hand after
`./eval/integration.sh` completes for that tier — it doesn't auto-fill):

- **Batch:** `eval/runs/<batch>/` (printed at the end of the run)
- **Branches:** `eval/gsplat-resample-01-<tier>-vanilla`,
  `eval/gsplat-resample-01-<tier>-claudia` in the italy-rs repo
- **Judge verdict:** `eval/runs/<batch>/gsplat-resample-01--<tier>/judge/1.json`
- **What vanilla did:** _one paragraph, after inspecting `vanilla.diff` and
  the branch._
- **What claudia did:** _one paragraph, after inspecting `claudia.diff` and
  the branch — note anything attributable to the ladder (delegation,
  reuse, marker discipline, honesty about scope) rather than model
  variance._
- **Tier note:** _once both tiers have a result, one line on whether the
  claudia-vs-vanilla gap (if any) held steady, widened, or vanished going
  from sonnet/medium to opus/high — that's the real question two tiers of
  the same task are here to answer._

The `.diff` files in each tier directory are exact copies of
`eval/runs/<batch>/gsplat-resample-01--<tier>/<condition>/1/diff.patch`,
taken against the `claudia-integration-eval` commit both branches forked
from — copied here because `eval/runs/` is gitignored and this is meant to
be inspectable without re-running anything.
