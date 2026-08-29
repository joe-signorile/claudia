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
    lines.append(
        f"Checklist pass-rate: **claudia {pct(agg['claudia'])}** vs "
        f"**vanilla {pct(agg['vanilla'])}** ({delta_str}), "
        f"{data['tasks_run']} tasks x {data['trials_per_task_per_condition']} trials, "
        f"both pinned to `{data['model']}`. Judge: `{data['judge_model']}`."
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
    lines.append("## By category")
    lines.append("")
    lines.append("| Category | vanilla | claudia |")
    lines.append("|---|---|---|")
    for cat, scores in sorted(data["by_category"].items()):
        lines.append(f"| {cat} | {pct(scores['vanilla'])} | {pct(scores['claudia'])} |")

    lines.append("")
    lines.append(
        "Trial counts vary by category — a case-study category run once "
        "per condition (e.g. `graphics-integration`) sits at a different "
        "confidence level than one averaged over 5 fixture trials. See "
        "the `trials` column in the by-task table below for each task's "
        "real count."
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
        "| Task | Category | trials | vanilla score | claudia score | "
        "vanilla in/out/cache-r/cache-w tok | claudia in/out/cache-r/cache-w tok | "
        "vanilla $ | claudia $ | Δ tokens (in/out/cache-r/cache-w) | Δ $ |"
    )
    lines.append("|---|---|---|---|---|---|---|---|---|---|---|")
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
            f"| {task_id} | {t['category']} | {t['trials']} | {pct(t['vanilla'])} | {pct(t['claudia'])} | "
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
    lines.append("## Token/cost usage — aggregate")
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
