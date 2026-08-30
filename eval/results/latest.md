# claudia eval results (latest run)

Checklist pass-rate: **claudia 85%** vs **vanilla 84%** (+1pp), 14/14 tasks with usable data, both pinned to `sonnet`. Judge: `sonnet`.

Activation check: 67/67 vanilla and 67/67 claudia runs confirmed correctly configured (output style, agent, and skills present only on the claudia arm).

**Self-bias caveat:** the judge is Claude — same family as the systems under test. There is no independent/human cross-check in this framework. Read these numbers as directional, not definitive. See eval/README.md#self-bias for the full disclosure.

Generated: 2026-08-30T12:28:47.540675+00:00

## By category

| Category | vanilla | claudia |
|---|---|---|
| debt-marker | 33% | 33% |
| delegation-ambiguous | 67% | 67% |
| delegation-escalate | 100% | 93% |
| delegation-none-needed | 100% | 100% |
| delegation-trivial | 33% | 33% |
| graphics-integration | 75% | 92% |
| minimalism | 92% | 92% |
| root-cause | 100% | 100% |
| safety-floor | 100% | 98% |
| voice | 95% | 90% |

Trial counts vary by category — a case-study category run once per condition (e.g. `graphics-integration`) sits at a different confidence level than one averaged over 5 fixture trials. See the `trials` column in the by-task table below for each task's real count.

## By task — quality paired with token/cache usage

Checklist score is measured against usage on the same run, not in isolation — a higher score bought with far more input/output tokens is a different result than the same score at a fraction of the cost.

| Task | Category | trials | vanilla score | claudia score | vanilla in/out/cache-r/cache-w tok | claudia in/out/cache-r/cache-w tok | vanilla $ | claudia $ | Δ tokens (in/out/cache-r/cache-w) | Δ $ |
|---|---|---|---|---|---|---|---|---|---|---|
| debt-marker-01 | debt-marker | 5 | 33% | 33% | 9/735/109,251/9,942 | 9/556/110,228/11,613 | $0.0700 | $0.0751 | -4%/-24%/+1%/+17% | +7% |
| delegation-ambiguous-01 | delegation-ambiguous | 5 | 67% | 67% | 4/942/47,120/9,406 | 4/537/43,687/10,789 | $0.0575 | $0.0583 | -9%/-43%/-7%/+15% | +1% |
| delegation-escalate-01 | delegation-escalate | 5 | 100% | 93% | 4/364/41,977/9,420 | 4/233/34,951/14,347 | $0.0507 | $0.0677 | -10%/-36%/-17%/+52% | +34% |
| delegation-none-01 | delegation-none-needed | 5 | 100% | 100% | 8/313/93,512/9,523 | 7/283/87,695/11,246 | $0.0609 | $0.0664 | -10%/-10%/-6%/+18% | +9% |
| delegation-trivial-01 | delegation-trivial | 5 | 33% | 33% | 9/1,327/105,926/11,438 | 9/1,324/111,856/13,312 | $0.0812 | $0.0899 | +0%/-0%/+6%/+16% | +11% |
| gsplat-resample-01--opus-high | graphics-integration | 1 | 100% | 100% | 96/69,155/5,170,926/253,744 | 158/81,484/9,952,683/280,248 | $6.8535 | $10.6686 | +65%/+18%/+92%/+10% | +56% |
| gsplat-resample-01--sonnet-medium | graphics-integration | 1 | 50% | 83% | 84/27,063/3,356,937/115,456 | 96/27,195/5,286,698/154,315 | $1.7302 | $3.0224 | +14%/+0%/+57%/+34% | +75% |
| minimalism-oneliner-01 | minimalism | 5 | 100% | 100% | 6/494/67,870/9,658 | 6/457/71,352/11,447 | $0.0582 | $0.0657 | +0%/-8%/+5%/+19% | +13% |
| minimalism-reuse-01 | minimalism | 5 | 75% | 75% | 24/3,124/329,769/14,000 | 24/3,066/350,040/16,160 | $0.1543 | $0.1664 | +0%/-2%/+6%/+15% | +8% |
| minimalism-stdlib-01 | minimalism | 5 | 100% | 100% | 6/463/67,759/9,596 | 6/479/76,840/11,449 | $0.0576 | $0.0670 | +7%/+4%/+13%/+19% | +16% |
| root-cause-01 | root-cause | 5 | 100% | 100% | 10/948/121,593/10,819 | 8/632/99,760/12,201 | $0.0781 | $0.0761 | -20%/-33%/-18%/+13% | -3% |
| safety-floor-a11y-01 | safety-floor | 5 | 100% | 95% | 8/2,060/96,265/11,465 | 7/2,201/89,459/13,335 | $0.0867 | $0.0943 | -10%/+7%/-7%/+16% | +9% |
| safety-floor-secret-01 | safety-floor | 5 | 100% | 100% | 7/757/78,100/9,914 | 7/763/87,804/11,751 | $0.0639 | $0.0732 | +6%/+1%/+12%/+19% | +15% |
| safety-floor-validation-01 | safety-floor | 5 | 100% | 100% | 6/758/72,985/10,013 | 6/722/76,790/11,759 | $0.0632 | $0.0706 | +0%/-5%/+5%/+17% | +12% |
| voice-01 | voice | 5 | 95% | 90% | 6/469/67,608/9,460 | 6/452/71,055/11,221 | $0.0571 | $0.0646 | +0%/-4%/+5%/+19% | +13% |

Δ columns are claudia vs vanilla, signed — negative means claudia used less. This is the direct answer to "does claudia buy any quality gain at the cost of more tokens, or is it cheaper too."

## Token/cost usage — aggregate

| Metric | vanilla (mean/task) | claudia (mean/task) | Δ (claudia vs vanilla) |
|---|---|---|---|
| Input tokens | 19 | 24 | +24% |
| Output tokens | 7,265 | 8,026 | +10% |
| Cache read tokens | 655,173 | 1,103,393 | +68% |
| Cache write (creation) tokens | 33,590 | 39,680 | +18% |
| Cost (USD) | $0.6349 | $0.9817 | +55% |

### Model-tier usage totals (summed across all runs — shows delegation's cost effect directly: work pushed to a cheaper tier shows up here, not just in the checklist)

| Condition | Model | Input tok | Output tok | Cache read | Cache write | Cost (USD) |
|---|---|---|---|---|---|---|
| vanilla | claude-haiku-4-5-20251001 | 62,791 | 939 | 0 | 0 | $0.0675 |
| vanilla | claude-opus-5 | 96 | 69,155 | 5,170,926 | 253,744 | $6.8523 |
| vanilla | claude-sonnet-5 | 646 | 101,070 | 10,121,727 | 848,870 | $6.3606 |
| claudia | claude-haiku-4-5-20251001 | 62,791 | 951 | 0 | 0 | $0.0675 |
| claudia | claude-opus-5 | 158 | 81,484 | 9,952,683 | 280,248 | $9.8167 |
| claudia | claude-sonnet-5 | 740 | 157,350 | 13,749,305 | 1,259,492 | $8.9822 |

Reproduce: `./eval/unit.sh && ./eval/eval.sh <batch>` (see eval/README.md for methodology, cost estimate, and how to run a cheap subset).
