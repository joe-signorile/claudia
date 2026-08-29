#!/usr/bin/env python3
"""Extracts what the judge needs from one run: the file diff, the main
thread's final text response, and any Agent/Task subagent delegations.

The exact stream-json event shape isn't guaranteed stable across Claude
Code versions, so this parses defensively: any parse failure degrades to
an empty/best-effort field rather than crashing the run. Sanity-check this
against a real transcript during `./eval/run.sh --smoke` before trusting
delegation-category results.

Usage: extract_summary.py <transcript.ndjson> <diff.patch> [stderr.log]
Prints {"diff": ..., "final_response": ..., "delegations": [...]} JSON.
"""
import json
import sys
from pathlib import Path

DELEGATE_TOOL_NAMES = {"agent", "task"}


def walk_tool_uses(obj, out):
    if isinstance(obj, dict):
        if str(obj.get("type", "")).lower() == "tool_use" and str(
            obj.get("name", "")
        ).lower() in DELEGATE_TOOL_NAMES:
            inp = obj.get("input", {}) or {}
            out.append(
                {
                    "subagent_type": inp.get("subagent_type"),
                    "model": inp.get("model"),
                }
            )
        for v in obj.values():
            walk_tool_uses(v, out)
    elif isinstance(obj, list):
        for v in obj:
            walk_tool_uses(v, out)


def extract_text(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "".join(
            block.get("text", "")
            for block in content
            if isinstance(block, dict) and block.get("type") == "text"
        )
    return ""


def main():
    transcript_path = Path(sys.argv[1])
    diff_path = Path(sys.argv[2])

    diff = diff_path.read_text() if diff_path.exists() and diff_path.stat().st_size else ""

    delegations = []
    final_response = ""

    if transcript_path.exists():
        for line in transcript_path.read_text(errors="replace").splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue

            walk_tool_uses(event, delegations)

            # Main-thread assistant turns only (not subagent-forwarded text,
            # which carries a parent_tool_use_id per --forward-subagent-text).
            if (
                isinstance(event, dict)
                and str(event.get("type", "")).lower() == "assistant"
                and not event.get("parent_tool_use_id")
            ):
                message = event.get("message", {}) or {}
                text = extract_text(message.get("content"))
                if text.strip():
                    final_response = text

    print(
        json.dumps(
            {"diff": diff, "final_response": final_response, "delegations": delegations},
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
