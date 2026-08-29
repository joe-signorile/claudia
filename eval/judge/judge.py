#!/usr/bin/env python3
"""Blinded LLM-judge for one task/trial pairing.

Reads the vanilla and claudia run summaries (diff + final response text +
delegation list, produced by eval/lib/extract_summary.py) for the same
trial, anonymizes and order-randomizes them into "Response A"/"Response
B", asks a fresh `claude -p` call (no shared context with the runs being
judged) to grade both against the task's checklist, then re-maps the
anonymized labels back to the real condition names before writing output.

Usage: judge.py <task-file> <vanilla-summary.json> <claudia-summary.json> <judge-model>
Prints {"vanilla": {...}, "claudia": {...}} JSON to stdout.
"""
import json
import random
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "lib"))
from frontmatter import parse  # noqa: E402

SYSTEM_PROMPT = (Path(__file__).parent / "system_prompt.txt").read_text()


def read_summary(path):
    data = json.loads(Path(path).read_text())
    data.setdefault("diff", "")
    data.setdefault("final_response", "")
    data.setdefault("delegations", [])
    return data


def render_response(summary):
    diff = summary["diff"].strip() or "(no file changes)"
    final = summary["final_response"].strip() or "(no final text captured)"
    if summary["delegations"]:
        delegations = "\n".join(
            f"- subagent_type={d.get('subagent_type')!r} model={d.get('model')!r}"
            for d in summary["delegations"]
        )
    else:
        delegations = "(none)"
    return (
        f"### Diff\n```diff\n{diff}\n```\n\n"
        f"### Final text reply\n{final}\n\n"
        f"### Subagent delegations\n{delegations}"
    )


def extract_verdict(stdout):
    try:
        envelope = json.loads(stdout)
        text = envelope["result"] if isinstance(envelope, dict) and "result" in envelope else stdout
    except (json.JSONDecodeError, KeyError, TypeError):
        text = stdout

    start = text.find("{")
    if start == -1:
        raise ValueError(f"no JSON object found in judge output: {text[:500]!r}")
    depth = 0
    for i in range(start, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return json.loads(text[start : i + 1])
    raise ValueError("unbalanced JSON object in judge output")


def main():
    task_file, vanilla_path, claudia_path, judge_model = sys.argv[1:5]
    task, prompt_body = parse(task_file)
    checklist = task.get("checklist", [])

    pair = [
        ("vanilla", read_summary(vanilla_path)),
        ("claudia", read_summary(claudia_path)),
    ]
    random.shuffle(pair)
    labels = ["Response A", "Response B"]
    label_to_condition = {labels[i]: pair[i][0] for i in range(2)}

    checklist_text = "\n".join(f"- {c['id']}: {c['text']}" for c in checklist)
    order = list(range(2))
    random.shuffle(order)

    sections = "\n\n".join(
        f"## {labels[i]}\n{render_response(pair[i][1])}" for i in order
    )

    judge_prompt = (
        f"{SYSTEM_PROMPT}\n\n"
        f"# Task given to both approaches\n{prompt_body}\n\n"
        f"# Checklist\n{checklist_text}\n\n"
        f"# Responses\n{sections}\n"
    )

    result = subprocess.run(
        ["claude", "-p", judge_prompt, "--model", judge_model, "--output-format", "json"],
        capture_output=True,
        text=True,
        check=True,
        timeout=300,
    )
    verdict = extract_verdict(result.stdout)

    out = {}
    for label, condition in label_to_condition.items():
        item = verdict.get(label, {})
        out[condition] = {c["id"]: bool(item.get(c["id"], False)) for c in checklist}

    print(json.dumps(out, indent=2))


if __name__ == "__main__":
    main()
