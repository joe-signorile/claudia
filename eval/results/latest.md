# claudia eval results (latest run)

Checklist pass-rate: **claudia 73%** vs **vanilla 73%** (+0pp), 7 tasks x 5 trials, both pinned to `sonnet`. Judge: `sonnet`.

**Run failures (rate limit/budget/crash):** vanilla 1/33, claudia 1/33 runs exited non-zero and were excluded from scoring. Re-run `./eval/run.sh --resume <batch>` to fill the gap rather than starting over — see eval/README.md.
Activation check: 33/33 vanilla and 33/33 claudia runs confirmed correctly configured (output style, agent, and skills present only on the claudia arm).

**Self-bias caveat:** the judge is Claude — same family as the systems under test. There is no independent/human cross-check in this framework. Read these numbers as directional, not definitive. See eval/README.md#self-bias for the full disclosure.

Generated: 2026-08-29T16:44:26.857791+00:00

## By category

| Category | vanilla | claudia |
|---|---|---|
| debt-marker | 33% | 33% |
| delegation-ambiguous | 67% | 67% |
| delegation-escalate | 100% | 100% |
| delegation-none-needed | 100% | 100% |
| delegation-trivial | 33% | 33% |
| minimalism | 88% | 88% |

Trial counts vary by category — a case-study category run once per condition (e.g. `graphics-integration`) sits at a different confidence level than one averaged over 5 fixture trials. See the `trials` column in the by-task table below for each task's real count.

## By task — quality paired with token/cache usage

Checklist score is measured against usage on the same run, not in isolation — a higher score bought with far more input/output tokens is a different result than the same score at a fraction of the cost.

| Task | Category | trials | vanilla score | claudia score | vanilla in/out/cache-r/cache-w tok | claudia in/out/cache-r/cache-w tok | vanilla $ | claudia $ | Δ tokens (in/out/cache-r/cache-w) | Δ $ |
|---|---|---|---|---|---|---|---|---|---|---|
| debt-marker-01 | debt-marker | 5 | 33% | 33% | 10/844/120,280/10,294 | 9/588/110,778/11,844 | $0.0747 | $0.0764 | -12%/-30%/-8%/+15% | +2% |
| delegation-ambiguous-01 | delegation-ambiguous | 5 | 67% | 67% | 5/1,076/57,530/10,017 | 5/831/54,750/11,438 | $0.0633 | $0.0660 | -8%/-23%/-5%/+14% | +4% |
| delegation-escalate-01 | delegation-escalate | 5 | 100% | 100% | 4/400/41,978/9,506 | 4/231/43,687/11,228 | $0.0514 | $0.0570 | +0%/-42%/+4%/+18% | +11% |
| delegation-none-01 | delegation-none-needed | 5 | 100% | 100% | 8/326/93,516/9,524 | 8/292/93,222/11,286 | $0.0611 | $0.0677 | -5%/-10%/-0%/+18% | +11% |
| delegation-trivial-01 | delegation-trivial | 5 | 33% | 33% | 10/1,372/122,720/11,584 | 8/1,278/99,912/13,222 | $0.0856 | $0.0867 | -20%/-7%/-19%/+14% | +1% |
| minimalism-oneliner-01 | minimalism | 5 | 100% | 100% | 6/462/73,033/9,665 | 6/469/71,352/11,452 | $0.0589 | $0.0658 | -6%/+2%/-2%/+18% | +12% |
| minimalism-reuse-01 | minimalism | 2 | 75% | 75% | 27/3,578/367,472/14,492 | 19/2,410/265,051/14,872 | $0.1683 | $0.1377 | -30%/-33%/-28%/+3% | -18% |

Δ columns are claudia vs vanilla, signed — negative means claudia used less. This is the direct answer to "does claudia buy any quality gain at the cost of more tokens, or is it cheaper too."

## Token/cost usage — aggregate

| Metric | vanilla (mean/task) | claudia (mean/task) | Δ (claudia vs vanilla) |
|---|---|---|---|
| Input tokens | 10 | 8 | -18% |
| Output tokens | 1,151 | 871 | -24% |
| Cache read tokens | 125,218 | 105,536 | -16% |
| Cache write (creation) tokens | 10,726 | 12,192 | +14% |
| Cost (USD) | $0.0805 | $0.0796 | -1% |

### Model-tier usage totals (summed across all runs — shows delegation's cost effect directly: work pushed to a cheaper tier shows up here, not just in the checklist)

| Condition | Model | Input tok | Output tok | Cache read | Cache write | Cost (USD) |
|---|---|---|---|---|---|---|
| vanilla | claude-haiku-4-5-20251001 | 29,701 | 430 | 0 | 0 | $0.0319 |
| vanilla | claude-sonnet-5 | 272 | 29,558 | 3,280,231 | 331,939 | $2.2799 |
| claudia | claude-haiku-4-5-20251001 | 29,701 | 438 | 0 | 0 | $0.0319 |
| claudia | claude-sonnet-5 | 234 | 23,270 | 2,898,606 | 382,102 | $2.3413 |

Reproduce: `./eval/run.sh` (see eval/README.md for methodology, cost estimate, and how to run a cheap subset).
