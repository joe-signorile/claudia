#!/usr/bin/env python3
"""Verifies claudia's config was actually loaded (or, for the vanilla arm,
wasn't) for one run — using Claude Code's own stream-json system/init
event. That event's output_style/agents/skills fields are populated
directly from what CLAUDE_CONFIG_DIR resolved to at process start, so this
is a direct structural signal, not an inference from model behavior. Every
run gets this check; a run that fails it is excluded from scoring by
aggregate.py rather than silently contributing wrong data.

Usage: check_activation.py <transcript.ndjson> <condition>
Prints {"activation_ok": bool, ...diagnostic fields...} JSON.
"""
import json
import sys
from pathlib import Path

CLAUDIA_SKILLS = {"claudia-debt", "doc-router", "fresh-work"}


def find_init_event(path):
    p = Path(path)
    if not p.exists():
        return None
    for line in p.read_text(errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get("type") == "system" and event.get("subtype") == "init":
            return event
    return None


def main():
    transcript, condition = sys.argv[1], sys.argv[2]
    init = find_init_event(transcript)
    if init is None:
        print(json.dumps({
            "activation_ok": False,
            "reason": "no system/init event found in transcript",
        }, indent=2))
        return

    output_style = init.get("output_style")
    agents = set(init.get("agents") or [])
    skills = set(init.get("skills") or [])
    has_claudia_agent = "claudia" in agents
    has_claudia_skills = CLAUDIA_SKILLS.issubset(skills)
    claudia_active = output_style == "claudia" and has_claudia_agent and has_claudia_skills

    if condition == "claudia":
        ok = claudia_active
        reason = "" if ok else "claudia config not fully loaded for the claudia arm"
    else:
        ok = not claudia_active
        reason = "" if ok else "claudia config leaked into the vanilla arm"

    print(json.dumps({
        "activation_ok": ok,
        "output_style": output_style,
        "has_claudia_agent": has_claudia_agent,
        "has_claudia_skills": has_claudia_skills,
        "reason": reason,
    }, indent=2))


if __name__ == "__main__":
    main()
