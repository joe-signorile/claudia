#!/usr/bin/env python3
"""Rolls up one batch's metrics.json + judge verdicts into a single
aggregate report.

Per trial, per condition: score = fraction true across (judge checklist
verdicts + deterministic grep_checks from metrics.json). Per task: mean
across trials. Aggregate: unweighted mean across tasks, so no category
with more tasks in the corpus can dominate the headline number.

Usage: aggregate.py <batch_dir> <model> <judge_model> <trials>
Prints eval/results/latest.json-shaped JSON to stdout.
"""
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent / "lib"))
from frontmatter import parse  # noqa: E402

REPO_DIR = Path(__file__).parent.parent
TASKS_DIR = REPO_DIR / "eval" / "tasks"
FIXTURES_DIR = REPO_DIR / "eval" / "fixtures"


def task_kind(meta):
    """Which of the two experiments a task belongs to.

    These are not comparable and must never share a headline mean: a
    fixture task is a toy repo averaged over several trials, while a
    case study is one trial against a real repo carrying ~40,000x the
    cache-read volume. An unweighted mean-per-task across both lets two
    n=1 runs dominate a 65-run corpus (measured: the combined +1.6pp/+55%
    headline was almost entirely the two case studies, while the fixture
    corpus alone was -0.8pp/+11%).

    A task whose `fixture:` doesn't resolve to a directory under
    eval/fixtures/ is a real-repo case study driven by eval/integration.sh
    — its "fixture" names an external repo (e.g. italy-rs). That's the
    same structural signal eval/unit.sh uses to skip those tasks, kept
    derived rather than a hand-maintained list so adding a case study
    can't forget to update it."""
    fixture = (meta.get("fixture") or "").strip()
    if not fixture:
        return "fixture"
    return "fixture" if (FIXTURES_DIR / fixture).is_dir() else "case-study"


def safe_json(path):
    """None for missing/empty/corrupt JSON — e.g. a zero-byte file left
    behind by a killed judge/claude process (`>` truncates the file before
    the process can fail). A batch directory from an interrupted run must
    still aggregate cleanly over whatever did complete."""
    if not path.exists() or not path.stat().st_size:
        return None
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError:
        return None


def exit_code_ok(condition, task_dir, trial):
    """False if claude exited non-zero (rate limit, budget cap, crash) —
    a run that didn't actually complete isn't a valid vanilla/claudia
    comparison point even if it happened to leave well-formed JSON
    behind (e.g. a session-limit response with no file changes)."""
    path = task_dir / condition / str(trial) / "exit_code"
    return path.exists() and path.read_text().strip() == "0"


def activation_ok(condition, task_dir, trial):
    """Excludes a run from scoring if claudia's config wasn't actually
    loaded for the claudia arm, or leaked into the vanilla arm — see
    eval/lib/check_activation.py. A misconfigured run must never silently
    contribute to the headline number."""
    activation = safe_json(task_dir / condition / str(trial) / "activation.json")
    return bool(activation and activation.get("activation_ok"))


def final_response_ok(condition, task_dir, trial):
    """False if summary.json's final_response is missing/blank — e.g. a
    sandbox seeding hiccup (missing .claude.json) that still exits 0 with
    well-formed JSON but never actually answered. Indistinguishable from a
    genuine quality loss unless caught here, so it must not silently score
    as one."""
    summary = safe_json(task_dir / condition / str(trial) / "summary.json")
    return bool(summary and str(summary.get("final_response") or "").strip())


def run_valid(condition, task_dir, trial):
    """A run only counts toward scoring if it completed (exit 0), had the
    config it was supposed to have, and actually produced an answer."""
    return (
        exit_code_ok(condition, task_dir, trial)
        and activation_ok(condition, task_dir, trial)
        and final_response_ok(condition, task_dir, trial)
    )


TOKEN_FIELDS = (
    "input_tokens",
    "output_tokens",
    "cache_creation_input_tokens",
    "cache_read_input_tokens",
    "total_cost_usd",
)


def load_tokens(condition, task_dir, trial):
    """None for excluded (invalid) runs — a run that wasn't a valid
    vanilla/claudia comparison point shouldn't skew token stats either."""
    if not run_valid(condition, task_dir, trial):
        return None
    return safe_json(task_dir / condition / str(trial) / "tokens.json")


def trial_score(condition, task_dir, trial):
    if not run_valid(condition, task_dir, trial):
        return None

    bools = []
    metrics = safe_json(task_dir / condition / str(trial) / "metrics.json")
    if metrics:
        bools.extend(metrics.get("grep_checks", {}).values())

    verdict = safe_json(task_dir / "judge" / f"{trial}.json")
    if verdict:
        bools.extend(verdict.get(condition, {}).values())

    if not bools:
        return None
    return sum(1 for b in bools if b) / len(bools)


def main():
    batch_dir, model, judge_model, trials = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])

    by_task = {}
    by_category = {}
    category_of = {}
    activation_failures = {"vanilla": 0, "claudia": 0}
    activation_total = {"vanilla": 0, "claudia": 0}
    run_failures = {"vanilla": 0, "claudia": 0}
    model_usage_totals = {"vanilla": {}, "claudia": {}}

    def add_model_usage(condition, model_usage):
        for model, m in (model_usage or {}).items():
            bucket = model_usage_totals[condition].setdefault(
                model,
                {"input_tokens": 0, "output_tokens": 0,
                 "cache_read_input_tokens": 0, "cache_creation_input_tokens": 0,
                 "cost_usd": 0.0},
            )
            for key in bucket:
                bucket[key] += m.get(key) or 0

    for task_dir in sorted(p for p in Path(batch_dir).iterdir() if p.is_dir()):
        task_id = task_dir.name
        # eval/integration.sh writes tiered runs as "<task_id>--<model>-<effort>"
        # (e.g. gsplat-resample-01--opus-high) so multiple tiers of the same
        # task coexist in one batch — strip the suffix to find the real task
        # file's category/checklist.
        base_task_id = task_id.split("--", 1)[0]
        task_file = TASKS_DIR / f"{base_task_id}.md"
        category = "unknown"
        kind = "fixture"
        if task_file.exists():
            meta, _ = parse(task_file)
            category = meta.get("category", "unknown")
            kind = task_kind(meta)
        category_of[task_id] = category

        task_scores = {"vanilla": [], "claudia": []}
        task_tokens = {"vanilla": {f: [] for f in TOKEN_FIELDS}, "claudia": {f: [] for f in TOKEN_FIELDS}}
        for trial in range(1, trials + 1):
            for condition in ("vanilla", "claudia"):
                if (task_dir / condition / str(trial)).exists():
                    activation_total[condition] += 1
                    if not activation_ok(condition, task_dir, trial):
                        activation_failures[condition] += 1
                    if not exit_code_ok(condition, task_dir, trial):
                        run_failures[condition] += 1
                score = trial_score(condition, task_dir, trial)
                if score is not None:
                    task_scores[condition].append(score)

                tokens = load_tokens(condition, task_dir, trial)
                if tokens is not None:
                    add_model_usage(condition, tokens.get("model_usage"))
                    for field in TOKEN_FIELDS:
                        val = tokens.get(field)
                        if val is not None:
                            task_tokens[condition][field].append(val)

        by_task[task_id] = {
            "category": category,
            "kind": kind,
            "vanilla": mean(task_scores["vanilla"]),
            "claudia": mean(task_scores["claudia"]),
            "trials": max(len(task_scores["vanilla"]), len(task_scores["claudia"])),
            "tokens": {
                condition: {field: mean(vals) for field, vals in fields.items()}
                for condition, fields in task_tokens.items()
            },
        }

    for task_id, scores in by_task.items():
        cat = scores["category"]
        by_category.setdefault(cat, {"vanilla": [], "claudia": []})
        if scores["vanilla"] is not None:
            by_category[cat]["vanilla"].append(scores["vanilla"])
        if scores["claudia"] is not None:
            by_category[cat]["claudia"].append(scores["claudia"])

    by_category_avg = {
        cat: {"vanilla": mean(v["vanilla"]), "claudia": mean(v["claudia"])}
        for cat, v in by_category.items()
    }

    # Per-experiment rollup — the number anything downstream should quote.
    # Same mean-of-per-task-means methodology as the combined aggregate,
    # just never mixing the two kinds. See task_kind() for why.
    by_kind = {}
    for kind in sorted({t["kind"] for t in by_task.values()}):
        ids = [tid for tid, t in by_task.items() if t["kind"] == kind]
        kv = mean([by_task[i]["vanilla"] for i in ids if by_task[i]["vanilla"] is not None])
        kc = mean([by_task[i]["claudia"] for i in ids if by_task[i]["claudia"] is not None])
        by_kind[kind] = {
            "task_count": len(ids),
            "runs_per_condition": sum(by_task[i]["trials"] for i in ids),
            "vanilla": kv,
            "claudia": kc,
            "delta": (kc - kv) if kv is not None and kc is not None else None,
            "tokens": {
                condition: {
                    field: mean([
                        by_task[i]["tokens"][condition][field]
                        for i in ids
                        if by_task[i]["tokens"][condition][field] is not None
                    ])
                    for field in TOKEN_FIELDS
                }
                for condition in ("vanilla", "claudia")
            },
        }

    task_vanilla = [t["vanilla"] for t in by_task.values() if t["vanilla"] is not None]
    task_claudia = [t["claudia"] for t in by_task.values() if t["claudia"] is not None]
    aggregate = {"vanilla": mean(task_vanilla), "claudia": mean(task_claudia)}
    delta = (
        aggregate["claudia"] - aggregate["vanilla"]
        if aggregate["vanilla"] is not None and aggregate["claudia"] is not None
        else None
    )

    # Corpus coverage: how much of the actual task corpus this aggregate is
    # built on, not just how many task-id directories happen to exist in
    # the batch. A batch that's mostly rate-limit failures can still leave
    # one lone valid task producing a real (if meaningless) delta — the
    # aggregate/delta above can't tell "16 tasks, full data" from "1 task
    # out of 16 had any data at all" without this. propagate_readme.py
    # gates on it before publishing anything.
    corpus_task_ids = {p.stem for p in TASKS_DIR.glob("*.md")}
    valid_base_task_ids = {
        task_id.split("--", 1)[0]
        for task_id, t in by_task.items()
        if t["vanilla"] is not None and t["claudia"] is not None
    }
    coverage = (
        len(valid_base_task_ids & corpus_task_ids) / len(corpus_task_ids)
        if corpus_task_ids
        else 0.0
    )

    # Token/cost aggregate: mean-of-per-task-means, same methodology as the
    # quality score, so one token-heavy task can't dominate the headline
    # efficiency number either.
    token_aggregate = {}
    for condition in ("vanilla", "claudia"):
        token_aggregate[condition] = {
            field: mean([
                t["tokens"][condition][field]
                for t in by_task.values()
                if t["tokens"][condition][field] is not None
            ])
            for field in TOKEN_FIELDS
        }

    out = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "model": model,
        "judge_model": judge_model,
        "trials_per_task_per_condition": trials,
        "tasks_run": len(by_task),
        "aggregate": aggregate,
        "delta": delta,
        "corpus_size": len(corpus_task_ids),
        "valid_task_count": len(valid_base_task_ids & corpus_task_ids),
        "coverage": coverage,
        "by_category": by_category_avg,
        "by_kind": by_kind,
        "by_task": by_task,
        "activation_failures": activation_failures,
        "activation_total": activation_total,
        "run_failures": run_failures,
        "token_usage": {
            "aggregate": token_aggregate,
            "model_usage_totals": model_usage_totals,
        },
        "self_bias_note": (
            "Judge is Claude (same family as the systems under test); "
            "see eval/README.md#self-bias."
        ),
    }
    print(json.dumps(out, indent=2))


def mean(xs):
    return sum(xs) / len(xs) if xs else None


if __name__ == "__main__":
    main()
