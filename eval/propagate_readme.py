#!/usr/bin/env python3
"""Idempotently writes/updates README.md's "## Results" section from
eval/results/latest.json, but only if claudia's case-study score clears a
minimum margin over vanilla, isn't a regression from whatever is already
published, and covers the full task corpus. Never silently overwrites a
good published number with a worse or thinner one — refuses loudly
instead.

The published number is the real-repo case-study rollup
(by_kind["case-study"]), never the combined aggregate — see headline()
below and eval/aggregate.py's task_kind() for why mixing the two
experiments produces a figure in neither one's units. The coverage gate
still spans the whole corpus, so a batch that skipped the fixture
regression suite can't publish either.

The coverage gate exists because a batch that's mostly rate-limit
failures can still leave one lone valid task producing a real (if
meaningless) delta — e.g. 1 task out of 16 having any data at all still
computes a mean and a "16 tasks" label without it. See
eval/aggregate.py's coverage/valid_task_count/corpus_size fields.

Usage: propagate_readme.py [--margin 0.05] [--min-coverage 1.0]
"""
import json
import re
import sys
from pathlib import Path

REPO_DIR = Path(__file__).parent.parent
README = REPO_DIR / "README.md"
LATEST_JSON = REPO_DIR / "eval" / "results" / "latest.json"

MARKER_START = "<!-- claudia:results:start -->"
MARKER_END = "<!-- claudia:results:end -->"
DELTA_RE = re.compile(r"<!-- claudia:results:delta=([-\d.]+) -->")

# Anchor: insert right after the blockquote tagline, which is stable prose
# unlikely to be reordered as often as headings might be.
ANCHOR_RE = re.compile(r"(^> .+\n)", re.MULTILINE)


def headline(data):
    """The case-study rollup — the published claim.

    Deliberately not data["aggregate"]: that mixes the real-repo case
    studies with the synthetic fixture suite at equal per-task weight, so
    it is dominated by whichever handful of case studies ran and is in
    neither experiment's units. The fixture suite is a saturated
    regression guard (most tasks 100% on both arms by design) and would
    only ever dilute a real result toward zero. See eval/aggregate.py's
    task_kind()."""
    return (data.get("by_kind") or {}).get("case-study")


def build_block(data):
    case = headline(data)
    delta = case["delta"]
    vanilla_pct = round(case["vanilla"] * 100)
    claudia_pct = round(case["claudia"] * 100)
    delta_pp = round(delta * 100)
    date = data["generated_at"][:10]
    n = case["task_count"]
    task_word = "case study" if n == 1 else "case studies"

    return (
        f"{MARKER_START}\n"
        f"<!-- claudia:results:delta={delta} -->\n"
        "## Results\n\n"
        f"On {n} real-repo {task_word} — a genuinely unimplemented roadmap "
        f"item in an existing codebase, planned then built — claudia's "
        f"minimalism/safety/delegation checklist pass-rate beat stock Claude "
        f"Code by {delta_pp}pp ({vanilla_pct}% -> {claudia_pct}%), both pinned "
        f"to `{data['model']}`.\n\n"
        f"**One trial per condition per task.** That is a case study, not a "
        f"statistical sample — it cannot separate a real effect from variance, "
        f"and the number will move. A separate {(data.get('by_kind') or {}).get('fixture', {}).get('task_count', 0)}-task "
        f"synthetic-fixture suite runs as a regression guard on the basics "
        f"(secrets, validation, a11y, root-cause fixes), where both arms "
        f"saturate and a tie is the expected result.\n\n"
        f"Judge is Claude itself — see "
        f"[eval/README.md](eval/README.md#self-bias) for that caveat and full "
        "methodology, plus how to reproduce this run yourself.\n\n"
        f"_Last measured: {date}._\n"
        f"{MARKER_END}\n"
    )


def main():
    margin = 0.05
    if "--margin" in sys.argv:
        margin = float(sys.argv[sys.argv.index("--margin") + 1])
    min_coverage = 1.0
    if "--min-coverage" in sys.argv:
        min_coverage = float(sys.argv[sys.argv.index("--min-coverage") + 1])

    if not LATEST_JSON.exists():
        print("eval/results/latest.json not found — run ./eval/unit.sh && ./eval/eval.sh <batch> first.", file=sys.stderr)
        sys.exit(1)

    data = json.loads(LATEST_JSON.read_text())
    case = headline(data)
    if not case or case.get("delta") is None:
        print(
            "latest.json has no case-study result to publish (no by_kind"
            "['case-study'] delta). The published claim comes from the "
            "real-repo case studies, not the fixture regression suite — run "
            "./eval/integration.sh for at least one case-study task, then "
            "./eval/eval.sh <batch>, before publishing.",
            file=sys.stderr,
        )
        sys.exit(1)
    delta = case["delta"]

    coverage = data.get("coverage", 0.0)
    if coverage < min_coverage:
        print(
            f"Coverage ({data.get('valid_task_count', 0)}/{data.get('corpus_size', '?')} "
            f"tasks = {coverage:.0%}) is below --min-coverage ({min_coverage:.0%}) — "
            "too much of this batch is rate-limit/budget failures to trust the "
            "aggregate. Refusing to publish. Re-run the failing tasks (see "
            "'Run failures' above) and try again once coverage is full.",
            file=sys.stderr,
        )
        sys.exit(1)

    readme_text = README.read_text()
    existing_delta_match = DELTA_RE.search(readme_text)
    if existing_delta_match:
        previous_delta = float(existing_delta_match.group(1))
        if delta < previous_delta:
            print(
                f"New delta ({delta:.3f}) is worse than the currently published "
                f"delta ({previous_delta:.3f}). Refusing to overwrite a regression "
                "— review the run before publishing it.",
                file=sys.stderr,
            )
            sys.exit(1)

    if delta < margin:
        print(
            f"Delta ({delta:.3f}) does not clear the minimum margin ({margin}). "
            "Not touching README.md.",
            file=sys.stderr,
        )
        sys.exit(0)

    block = build_block(data)

    if MARKER_START in readme_text and MARKER_END in readme_text:
        pattern = re.compile(
            re.escape(MARKER_START) + r".*?" + re.escape(MARKER_END) + r"\n?",
            re.DOTALL,
        )
        new_text = pattern.sub(block, readme_text)
    else:
        m = ANCHOR_RE.search(readme_text)
        if not m:
            print("Could not find the blockquote tagline anchor in README.md.", file=sys.stderr)
            sys.exit(1)
        insert_at = m.end()
        new_text = readme_text[:insert_at] + "\n" + block + "\n" + readme_text[insert_at:]

    README.write_text(new_text)
    print(f"README.md Results section updated: {delta*100:+.0f}pp.")


if __name__ == "__main__":
    main()
