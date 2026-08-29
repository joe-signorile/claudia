#!/usr/bin/env python3
"""Idempotently writes/updates README.md's "## Results" section from
eval/results/latest.json, but only if claudia's aggregate score clears a
minimum margin over vanilla, and only if it isn't a regression from
whatever is already published. Never silently overwrites a good published
number with a worse one — refuses loudly instead.

Usage: propagate_readme.py [--margin 0.05]
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


def build_block(data):
    agg = data["aggregate"]
    delta = data["delta"]
    vanilla_pct = round(agg["vanilla"] * 100)
    claudia_pct = round(agg["claudia"] * 100)
    delta_pp = round(delta * 100)
    date = data["generated_at"][:10]

    return (
        f"{MARKER_START}\n"
        f"<!-- claudia:results:delta={delta} -->\n"
        "## Results\n\n"
        f"Claudia's minimalism/safety/delegation checklist pass-rate beat stock "
        f"Claude Code by {delta_pp}pp ({vanilla_pct}% -> {claudia_pct}%) across "
        f"{data['tasks_run']} tasks, {data['trials_per_task_per_condition']} trials each, "
        f"both pinned to `{data['model']}`. Judge is Claude itself — see "
        f"[eval/README.md](eval/README.md#self-bias) for that caveat and full "
        "methodology, plus how to reproduce this run yourself.\n\n"
        f"_Last measured: {date}._\n"
        f"{MARKER_END}\n"
    )


def main():
    margin = 0.05
    if "--margin" in sys.argv:
        margin = float(sys.argv[sys.argv.index("--margin") + 1])

    if not LATEST_JSON.exists():
        print("eval/results/latest.json not found — run ./eval/unit.sh && ./eval/eval.sh <batch> first.", file=sys.stderr)
        sys.exit(1)

    data = json.loads(LATEST_JSON.read_text())
    delta = data.get("delta")
    if delta is None:
        print("latest.json has no delta (incomplete run) — refusing to update README.", file=sys.stderr)
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
