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


def run_valid(condition, task_dir, trial):
    """A run only counts toward scoring if it both completed (exit 0) and
    had the config it was supposed to have."""
    return exit_code_ok(condition, task_dir, trial) and activation_ok(condition, task_dir, trial)


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
        task_file = TASKS_DIR / f"{task_id}.md"
        category = "unknown"
        if task_file.exists():
            meta, _ = parse(task_file)
            category = meta.get("category", "unknown")
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

    task_vanilla = [t["vanilla"] for t in by_task.values() if t["vanilla"] is not None]
    task_claudia = [t["claudia"] for t in by_task.values() if t["claudia"] is not None]
    aggregate = {"vanilla": mean(task_vanilla), "claudia": mean(task_claudia)}
    delta = (
        aggregate["claudia"] - aggregate["vanilla"]
        if aggregate["vanilla"] is not None and aggregate["claudia"] is not None
        else None
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
        "by_category": by_category_avg,
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
