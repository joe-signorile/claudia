# claudia eval results (latest run)

Checklist pass-rate: **claudia 83%** vs **vanilla 50%** (+33pp), 16 tasks x 5 trials, both pinned to `sonnet`. Judge: `opus`.

**Run failures (rate limit/budget/crash):** vanilla 70/72, claudia 71/72 runs exited non-zero and were excluded from scoring. Re-run `./eval/unit.sh --resume <batch>` to fill the gap rather than starting over — see eval/README.md.
Activation check: 72/72 vanilla and 72/72 claudia runs confirmed correctly configured (output style, agent, and skills present only on the claudia arm).

**Self-bias caveat:** the judge is Claude — same family as the systems under test. There is no independent/human cross-check in this framework. Read these numbers as directional, not definitive. See eval/README.md#self-bias for the full disclosure.

Generated: 2026-08-30T00:06:29.801809+00:00

## By category

| Category | vanilla | claudia |
|---|---|---|
| debt-marker | n/a | n/a |
| delegation-ambiguous | n/a | n/a |
| delegation-escalate | n/a | n/a |
| delegation-none-needed | n/a | n/a |
| delegation-trivial | n/a | n/a |
| graphics-integration | 50% | 83% |
| minimalism | n/a | n/a |
| root-cause | n/a | n/a |
| safety-floor | n/a | n/a |
| voice | n/a | n/a |

Trial counts vary by category — a case-study category run once per condition (e.g. `graphics-integration`) sits at a different confidence level than one averaged over 5 fixture trials. See the `trials` column in the by-task table below for each task's real count.

## By task — quality paired with token/cache usage

Checklist score is measured against usage on the same run, not in isolation — a higher score bought with far more input/output tokens is a different result than the same score at a fraction of the cost.

| Task | Category | trials | vanilla score | claudia score | vanilla in/out/cache-r/cache-w tok | claudia in/out/cache-r/cache-w tok | vanilla $ | claudia $ | Δ tokens (in/out/cache-r/cache-w) | Δ $ |
|---|---|---|---|---|---|---|---|---|---|---|
| debt-marker-01 | debt-marker | 0 | n/a | n/a | n/a/n/a/n/a/n/a | n/a/n/a/n/a/n/a | n/a | n/a | n/a/n/a/n/a/n/a | n/a |
| delegation-ambiguous-01 | delegation-ambiguous | 0 | n/a | n/a | n/a/n/a/n/a/n/a | n/a/n/a/n/a/n/a | n/a | n/a | n/a/n/a/n/a/n/a | n/a |
| delegation-escalate-01 | delegation-escalate | 0 | n/a | n/a | n/a/n/a/n/a/n/a | n/a/n/a/n/a/n/a | n/a | n/a | n/a/n/a/n/a/n/a | n/a |
| delegation-none-01 | delegation-none-needed | 0 | n/a | n/a | n/a/n/a/n/a/n/a | n/a/n/a/n/a/n/a | n/a | n/a | n/a/n/a/n/a/n/a | n/a |
| delegation-trivial-01 | delegation-trivial | 0 | n/a | n/a | n/a/n/a/n/a/n/a | n/a/n/a/n/a/n/a | n/a | n/a | n/a/n/a/n/a/n/a | n/a |
| gsplat-resample-01 | graphics-integration | 0 | n/a | n/a | n/a/n/a/n/a/n/a | n/a/n/a/n/a/n/a | n/a | n/a | n/a/n/a/n/a/n/a | n/a |
| gsplat-resample-01--opus-high | graphics-integration | 0 | n/a | n/a | 96/69,155/5,170,926/253,744 | n/a/n/a/n/a/n/a | $6.8535 | n/a | n/a/n/a/n/a/n/a | n/a |
| gsplat-resample-01--sonnet-medium | graphics-integration | 1 | 50% | 83% | 84/27,063/3,356,937/115,456 | 96/27,195/5,286,698/154,315 | $1.7302 | $3.0224 | +14%/+0%/+57%/+34% | +75% |
| minimalism-oneliner-01 | minimalism | 0 | n/a | n/a | n/a/n/a/n/a/n/a | n/a/n/a/n/a/n/a | n/a | n/a | n/a/n/a/n/a/n/a | n/a |
| minimalism-reuse-01 | minimalism | 0 | n/a | n/a | n/a/n/a/n/a/n/a | n/a/n/a/n/a/n/a | n/a | n/a | n/a/n/a/n/a/n/a | n/a |
| minimalism-stdlib-01 | minimalism | 0 | n/a | n/a | n/a/n/a/n/a/n/a | n/a/n/a/n/a/n/a | n/a | n/a | n/a/n/a/n/a/n/a | n/a |
| root-cause-01 | root-cause | 0 | n/a | n/a | n/a/n/a/n/a/n/a | n/a/n/a/n/a/n/a | n/a | n/a | n/a/n/a/n/a/n/a | n/a |
| safety-floor-a11y-01 | safety-floor | 0 | n/a | n/a | n/a/n/a/n/a/n/a | n/a/n/a/n/a/n/a | n/a | n/a | n/a/n/a/n/a/n/a | n/a |
| safety-floor-secret-01 | safety-floor | 0 | n/a | n/a | n/a/n/a/n/a/n/a | n/a/n/a/n/a/n/a | n/a | n/a | n/a/n/a/n/a/n/a | n/a |
| safety-floor-validation-01 | safety-floor | 0 | n/a | n/a | n/a/n/a/n/a/n/a | n/a/n/a/n/a/n/a | n/a | n/a | n/a/n/a/n/a/n/a | n/a |
| voice-01 | voice | 0 | n/a | n/a | n/a/n/a/n/a/n/a | n/a/n/a/n/a/n/a | n/a | n/a | n/a/n/a/n/a/n/a | n/a |

Δ columns are claudia vs vanilla, signed — negative means claudia used less. This is the direct answer to "does claudia buy any quality gain at the cost of more tokens, or is it cheaper too."

## Token/cost usage — aggregate

| Metric | vanilla (mean/task) | claudia (mean/task) | Δ (claudia vs vanilla) |
|---|---|---|---|
| Input tokens | 90 | 96 | +7% |
| Output tokens | 48,109 | 27,195 | -43% |
| Cache read tokens | 4,263,932 | 5,286,698 | +24% |
| Cache write (creation) tokens | 184,600 | 154,315 | -16% |
| Cost (USD) | $4.2919 | $3.0224 | -30% |

### Model-tier usage totals (summed across all runs — shows delegation's cost effect directly: work pushed to a cheaper tier shows up here, not just in the checklist)

| Condition | Model | Input tok | Output tok | Cache read | Cache write | Cost (USD) |
|---|---|---|---|---|---|---|
| vanilla | claude-haiku-4-5-20251001 | 2,296 | 42 | 0 | 0 | $0.0025 |
| vanilla | claude-opus-5 | 96 | 69,155 | 5,170,926 | 253,744 | $6.8523 |
| vanilla | claude-sonnet-5 | 106 | 37,299 | 3,623,050 | 175,595 | $1.7290 |
| claudia | claude-haiku-4-5-20251001 | 1,148 | 22 | 0 | 0 | $0.0013 |
| claudia | claude-sonnet-5 | 154 | 67,719 | 6,249,545 | 315,928 | $3.0211 |

Reproduce: `./eval/unit.sh && ./eval/eval.sh <batch>` (see eval/README.md for methodology, cost estimate, and how to run a cheap subset).
