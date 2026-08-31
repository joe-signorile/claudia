#!/usr/bin/env python3
"""Renders eval/results/latest.md from eval/results/latest.json.

Usage: report.py <latest.json>
Prints markdown to stdout.
"""
import json
import sys


def pct(x):
    return "n/a" if x is None else f"{x * 100:.0f}%"


def num(x, decimals=0):
    return "n/a" if x is None else f"{x:,.{decimals}f}"


def usd(x):
    return "n/a" if x is None else f"${x:.4f}"


def pp(x):
    """A quality delta in percentage points (not a % change — these are
    already percentages, so a ratio would be meaningless)."""
    return "n/a" if x is None else f"{x * 100:+.0f}pp"


def delta_pct(vanilla, claudia):
    """claudia vs vanilla, as a signed % change. None if either side is
    missing or vanilla is 0 (can't take a % change from zero)."""
    if vanilla is None or claudia is None or vanilla == 0:
        return "n/a"
    return f"{(claudia - vanilla) / vanilla * 100:+.0f}%"


def main():
    data = json.loads(open(sys.argv[1]).read())
    agg = data["aggregate"]
    delta = data.get("delta")
    delta_str = "n/a" if delta is None else f"{delta * 100:+.0f}pp"

    lines = []
    lines.append("# claudia eval results (latest run)")
    lines.append("")
    valid_task_count = data.get("valid_task_count")
    corpus_size = data.get("corpus_size")
    coverage = data.get("coverage")
    coverage_str = (
        f"{valid_task_count}/{corpus_size} tasks with usable data"
        if valid_task_count is not None
        else f"{data['tasks_run']} tasks x {data['trials_per_task_per_condition']} trials"
    )

    by_kind = data.get("by_kind", {})
    case = by_kind.get("case-study")
    fixture = by_kind.get("fixture")

    if case:
        lines.append(
            f"**Headline — real-repo case studies:** claudia "
            f"**{pct(case['claudia'])}** vs vanilla **{pct(case['vanilla'])}** "
            f"({pp(case['delta'])}) across {case['task_count']} task(s), one "
            f"trial per condition, both pinned to `{data['model']}`. "
            f"Judge: `{data['judge_model']}`."
        )
        lines.append("")
        lines.append(
            "**n=1 per task per condition.** These are case studies, not a "
            "statistical sample: one run each against a real repo with real "
            "conventions and a task too big to hold in one glance. That is "
            "deliberately where the discipline is expected to matter, but a "
            "single trial cannot separate a real effect from run-to-run "
            "variance. Read the direction as the claim and the magnitude as "
            "noisy."
        )
        lines.append("")
    if fixture:
        lines.append(
            f"**Regression suite — synthetic fixtures:** claudia "
            f"{pct(fixture['claudia'])} vs vanilla {pct(fixture['vanilla'])} "
            f"({pp(fixture['delta'])}) across {fixture['task_count']} tasks, "
            f"{fixture['runs_per_condition']} runs per condition. These are "
            "1-4 file toy repos, and most of them saturate at 100% on both "
            "arms — they exist to catch a regression in the basics (secret "
            "handling, input validation, a11y, root-cause fixes), not to "
            "demonstrate a difference. A tie here is the expected result."
        )
        lines.append("")
    if case and fixture:
        lines.append(
            f"Combined across {coverage_str}: claudia {pct(agg['claudia'])} vs "
            f"vanilla {pct(agg['vanilla'])} ({delta_str}) — kept for continuity "
            "only, and not a number to quote. It is an unweighted mean per "
            "task, so a 1-trial case study carrying ~40,000x the cache-read "
            "volume of a fixture counts exactly as much as a 5-trial toy "
            "task; the combined figure tracks the two case studies almost "
            "entirely and is in neither experiment's units."
        )
    else:
        lines.append(
            f"Checklist pass-rate: **claudia {pct(agg['claudia'])}** vs "
            f"**vanilla {pct(agg['vanilla'])}** ({delta_str}), "
            f"{coverage_str}, both pinned to `{data['model']}`. "
            f"Judge: `{data['judge_model']}`."
        )
    lines.append("")
    if coverage is not None and coverage < 1.0:
        lines.append(
            f"**WARNING — thin coverage:** only {valid_task_count}/{corpus_size} "
            f"tasks ({coverage:.0%}) in the full corpus produced usable data in "
            "this batch — the rest failed (rate limit/budget/crash, see "
            "'Run failures' below) and are excluded, not averaged in as zero. "
            "The aggregate above is real but not representative of the full "
            "corpus. `propagate_readme.py` refuses to publish below 100% "
            "coverage by default — don't trust this number until it's whole."
        )
        lines.append("")
    run_fails = data.get("run_failures", {})
    totals = data.get("activation_total", {})
    if any(run_fails.values()):
        lines.append(
            f"**Run failures (rate limit/budget/crash):** vanilla "
            f"{run_fails.get('vanilla', 0)}/{totals.get('vanilla', 0)}, claudia "
            f"{run_fails.get('claudia', 0)}/{totals.get('claudia', 0)} runs exited "
            "non-zero and were excluded from scoring. Re-run "
            "`./eval/unit.sh --resume <batch>` to fill the gap rather than "
            "starting over — see eval/README.md."
        )
    fails = data.get("activation_failures", {})
    if any(fails.values()):
        lines.append(
            f"**WARNING — activation check failures:** vanilla "
            f"{fails.get('vanilla', 0)}/{totals.get('vanilla', 0)}, claudia "
            f"{fails.get('claudia', 0)}/{totals.get('claudia', 0)} runs had "
            "claudia's config either missing where expected or leaking in "
            "where it shouldn't be (see eval/lib/check_activation.py). "
            "Those runs were excluded from scoring below, but this many "
            "failures means the harness itself may be misconfigured — "
            "don't trust these numbers until this is zero."
        )
    else:
        lines.append(
            f"Activation check: {totals.get('vanilla', 0)}/{totals.get('vanilla', 0)} "
            f"vanilla and {totals.get('claudia', 0)}/{totals.get('claudia', 0)} claudia "
            "runs confirmed correctly configured (output style, agent, and skills "
            "present only on the claudia arm)."
        )
    lines.append("")
    lines.append(
        "**Self-bias caveat:** the judge is Claude — same family as the "
        "systems under test. There is no independent/human cross-check in "
        "this framework. Read these numbers as directional, not definitive. "
        "See eval/README.md#self-bias for the full disclosure."
    )
    lines.append("")
    lines.append("Generated: " + data["generated_at"])
    lines.append("")
    if by_kind:
        lines.append("## By experiment — quality and cost, never mixed")
        lines.append("")
        lines.append(
            "| Experiment | tasks | runs/condition | vanilla | claudia | "
            "Δ quality | vanilla $/task | claudia $/task | Δ $ |"
        )
        lines.append("|---|---|---|---|---|---|---|---|---|")
        for kind in ("case-study", "fixture"):
            k = by_kind.get(kind)
            if not k:
                continue
            kv = k["tokens"]["vanilla"]["total_cost_usd"]
            kc = k["tokens"]["claudia"]["total_cost_usd"]
            lines.append(
                f"| {kind} | {k['task_count']} | {k['runs_per_condition']} | "
                f"{pct(k['vanilla'])} | {pct(k['claudia'])} | {pp(k['delta'])} | "
                f"{usd(kv)} | {usd(kc)} | {delta_pct(kv, kc)} |"
            )
        lines.append("")
        lines.append(
            "The two rows answer different questions and are not averaged "
            "together anywhere above. Case studies ask whether the discipline "
            "survives real project weight; fixtures ask whether it broke "
            "something basic. Cost per task is not comparable across rows "
            "either — a case study is a multi-hour session against a real "
            "repo, a fixture is minutes against a toy one."
        )
        lines.append("")
    lines.append("## By category")
    lines.append("")
    lines.append("| Category | vanilla | claudia |")
    lines.append("|---|---|---|")
    for cat, scores in sorted(data["by_category"].items()):
        lines.append(f"| {cat} | {pct(scores['vanilla'])} | {pct(scores['claudia'])} |")

    lines.append("")
    lines.append(
        "Categories span both experiments, so a category row can mix "
        "confidence levels — a case-study category run once per condition "
        "(e.g. `graphics-integration`) is not the same evidence as one "
        "averaged over 5 fixture trials, and saturated regression-guard "
        "tasks now run 1 trial by design. Use the `Kind` and `trials` "
        "columns in the by-task table below to see what each row rests on."
    )
    lines.append("")
    lines.append("## By task — quality paired with token/cache usage")
    lines.append("")
    lines.append(
        "Checklist score is measured against usage on the same run, not in "
        "isolation — a higher score bought with far more input/output "
        "tokens is a different result than the same score at a fraction of "
        "the cost."
    )
    lines.append("")
    lines.append(
        "| Task | Kind | Category | trials | vanilla score | claudia score | "
        "vanilla in/out/cache-r/cache-w tok | claudia in/out/cache-r/cache-w tok | "
        "vanilla $ | claudia $ | Δ tokens (in/out/cache-r/cache-w) | Δ $ |"
    )
    lines.append("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for task_id, t in sorted(data["by_task"].items()):
        vt, ct = t["tokens"]["vanilla"], t["tokens"]["claudia"]
        v_tok = (
            f"{num(vt['input_tokens'])}/{num(vt['output_tokens'])}/"
            f"{num(vt['cache_read_input_tokens'])}/{num(vt['cache_creation_input_tokens'])}"
        )
        c_tok = (
            f"{num(ct['input_tokens'])}/{num(ct['output_tokens'])}/"
            f"{num(ct['cache_read_input_tokens'])}/{num(ct['cache_creation_input_tokens'])}"
        )
        d_tok = "/".join(
            delta_pct(vt[f], ct[f])
            for f in (
                "input_tokens", "output_tokens",
                "cache_read_input_tokens", "cache_creation_input_tokens",
            )
        )
        lines.append(
            f"| {task_id} | {t.get('kind', 'fixture')} | {t['category']} | {t['trials']} | "
            f"{pct(t['vanilla'])} | {pct(t['claudia'])} | "
            f"{v_tok} | {c_tok} | {usd(vt['total_cost_usd'])} | {usd(ct['total_cost_usd'])} | "
            f"{d_tok} | {delta_pct(vt['total_cost_usd'], ct['total_cost_usd'])} |"
        )

    lines.append("")
    lines.append(
        "Δ columns are claudia vs vanilla, signed — negative means claudia "
        "used less. This is the direct answer to \"does claudia buy any "
        "quality gain at the cost of more tokens, or is it cheaper too.\""
    )

    lines.append("")
    lines.append("## Final-response length — prose only, code blocks excluded")
    lines.append("")
    lines.append(
        "Mean words in the main thread's final text reply, fenced code "
        "blocks stripped before counting. This is the continuous version of "
        "what the `voice` checklist can only answer yes/no: that item "
        "saturates as soon as both arms clear its threshold, so it cannot "
        "show a length gap in either direction. This can. Lower is the "
        "goal, but only down to the floor — the safety-floor tasks are "
        "meant to run long, since terseness yields to full explanation for "
        "security findings and irreversible operations."
    )
    lines.append("")
    lines.append("| Task | Kind | vanilla words | claudia words | Δ |")
    lines.append("|---|---|---|---|---|")
    for task_id, t in sorted(data["by_task"].items()):
        pr = t.get("prose")
        if not pr:
            continue
        vw, cw = pr["vanilla"]["words"], pr["claudia"]["words"]
        lines.append(
            f"| {task_id} | {t.get('kind', 'fixture')} | {num(vw)} | "
            f"{num(cw)} | {delta_pct(vw, cw)} |"
        )
    for kind in ("case-study", "fixture"):
        k = by_kind.get(kind) or {}
        pr = k.get("prose")
        if not pr:
            continue
        vw, cw = pr["vanilla"]["words"], pr["claudia"]["words"]
        lines.append(
            f"| **all {kind}** | {kind} | **{num(vw)}** | **{num(cw)}** | "
            f"**{delta_pct(vw, cw)}** |"
        )
    lines.append("")
    lines.append(
        "Per-kind rows are means of per-task means, never averaged across "
        "kinds — a one-trial case study writes a report, a fixture task "
        "answers in a line."
    )

    lines.append("")
    lines.append("## Token/cost usage — aggregate (mixed, see caveat)")
    lines.append("")
    lines.append(
        "This table averages both experiments together and is kept for "
        "continuity. Because it is an unweighted mean per task, the "
        "case-study rows dominate every figure in it — the per-experiment "
        "cost split in \"By experiment\" above is the one to read."
    )
    lines.append("")
    tu = data.get("token_usage", {}).get("aggregate", {})
    v, c = tu.get("vanilla", {}), tu.get("claudia", {})
    lines.append("| Metric | vanilla (mean/task) | claudia (mean/task) | Δ (claudia vs vanilla) |")
    lines.append("|---|---|---|---|")
    lines.append(
        f"| Input tokens | {num(v.get('input_tokens'))} | {num(c.get('input_tokens'))} | "
        f"{delta_pct(v.get('input_tokens'), c.get('input_tokens'))} |"
    )
    lines.append(
        f"| Output tokens | {num(v.get('output_tokens'))} | {num(c.get('output_tokens'))} | "
        f"{delta_pct(v.get('output_tokens'), c.get('output_tokens'))} |"
    )
    lines.append(
        f"| Cache read tokens | {num(v.get('cache_read_input_tokens'))} | "
        f"{num(c.get('cache_read_input_tokens'))} | "
        f"{delta_pct(v.get('cache_read_input_tokens'), c.get('cache_read_input_tokens'))} |"
    )
    lines.append(
        f"| Cache write (creation) tokens | {num(v.get('cache_creation_input_tokens'))} | "
        f"{num(c.get('cache_creation_input_tokens'))} | "
        f"{delta_pct(v.get('cache_creation_input_tokens'), c.get('cache_creation_input_tokens'))} |"
    )
    lines.append(
        f"| Cost (USD) | {usd(v.get('total_cost_usd'))} | {usd(c.get('total_cost_usd'))} | "
        f"{delta_pct(v.get('total_cost_usd'), c.get('total_cost_usd'))} |"
    )

    totals = data.get("token_usage", {}).get("model_usage_totals", {})
    lines.append("")
    lines.append(
        "### Model-tier usage totals (summed across all runs — shows "
        "delegation's cost effect directly: work pushed to a cheaper tier "
        "shows up here, not just in the checklist)"
    )
    lines.append("")
    lines.append("| Condition | Model | Input tok | Output tok | Cache read | Cache write | Cost (USD) |")
    lines.append("|---|---|---|---|---|---|---|")
    for condition in ("vanilla", "claudia"):
        for model, m in sorted(totals.get(condition, {}).items()):
            lines.append(
                f"| {condition} | {model} | {num(m['input_tokens'])} | {num(m['output_tokens'])} | "
                f"{num(m['cache_read_input_tokens'])} | {num(m['cache_creation_input_tokens'])} | "
                f"{usd(m['cost_usd'])} |"
            )

    lines.append("")
    lines.append(
        "Reproduce: `./eval/unit.sh && ./eval/eval.sh <batch>` (see eval/README.md for methodology, "
        "cost estimate, and how to run a cheap subset)."
    )
    print("\n".join(lines))


if __name__ == "__main__":
    main()
