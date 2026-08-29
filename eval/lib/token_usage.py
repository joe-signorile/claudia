#!/usr/bin/env python3
"""Extracts token/cost usage for one run from its stream-json transcript's
final "result" event — including the modelUsage breakdown across the main
thread and any delegated subagents (e.g. haiku vs sonnet). This is what
lets quality checklist scores be paired with cost/token efficiency instead
of judged in isolation, and lets delegation's cost effect (cheaper tiers
for appropriate work) show up as a number, not just a checklist tick.

Usage: token_usage.py <transcript.ndjson> [<transcript2.ndjson> ...]

Multiple transcripts are summed, not just the last one read — needed for
eval/integration.sh's two-stage plan-then-execute session, where the real
cost is both `claude -p` calls, not just the final one. Each transcript
still takes its own last "result" event in case of in-stage retries.
Prints token/cost JSON to stdout.
"""
import json
import sys
from pathlib import Path


def find_result_event(path):
    p = Path(path)
    if not p.exists():
        return None
    result = None
    for line in p.read_text(errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get("type") == "result":
            result = event  # last one wins, in case of retries
    return result


def add(total, value):
    if value is None:
        return total
    return value if total is None else total + value


def main():
    results = [r for r in (find_result_event(p) for p in sys.argv[1:]) if r is not None]

    totals = {
        "input_tokens": None,
        "output_tokens": None,
        "cache_creation_input_tokens": None,
        "cache_read_input_tokens": None,
        "total_cost_usd": None,
        "num_turns": None,
        "model_usage": {},
    }

    for result in results:
        usage = result.get("usage", {}) or {}
        totals["input_tokens"] = add(totals["input_tokens"], usage.get("input_tokens"))
        totals["output_tokens"] = add(totals["output_tokens"], usage.get("output_tokens"))
        totals["cache_creation_input_tokens"] = add(
            totals["cache_creation_input_tokens"], usage.get("cache_creation_input_tokens")
        )
        totals["cache_read_input_tokens"] = add(
            totals["cache_read_input_tokens"], usage.get("cache_read_input_tokens")
        )
        totals["total_cost_usd"] = add(totals["total_cost_usd"], result.get("total_cost_usd"))
        totals["num_turns"] = add(totals["num_turns"], result.get("num_turns"))

        for model, m in (result.get("modelUsage") or {}).items():
            bucket = totals["model_usage"].setdefault(model, {
                "input_tokens": None,
                "output_tokens": None,
                "cache_read_input_tokens": None,
                "cache_creation_input_tokens": None,
                "cost_usd": None,
            })
            bucket["input_tokens"] = add(bucket["input_tokens"], m.get("inputTokens"))
            bucket["output_tokens"] = add(bucket["output_tokens"], m.get("outputTokens"))
            bucket["cache_read_input_tokens"] = add(
                bucket["cache_read_input_tokens"], m.get("cacheReadInputTokens")
            )
            bucket["cache_creation_input_tokens"] = add(
                bucket["cache_creation_input_tokens"], m.get("cacheCreationInputTokens")
            )
            bucket["cost_usd"] = add(bucket["cost_usd"], m.get("costUSD"))

    print(json.dumps(totals, indent=2))


if __name__ == "__main__":
    main()
