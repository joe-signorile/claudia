#!/usr/bin/env python3
"""Checks whether a run directory or judge verdict file represents a
complete, valid result. Used by run.sh's --resume to skip already-done
work instead of re-running the whole matrix after a crash/rate-limit — and
to know a truncated file (e.g. a zero-byte judge/<trial>.json left behind
by a killed process) needs to be retried, not trusted.

Usage:
  run_status.py run <run_dir>       # exit 0 iff run_dir is complete+valid
  run_status.py judge <judge_file>  # exit 0 iff judge_file is complete+valid
Exit code only, no stdout — callers use `if python3 run_status.py ...`.
"""
import json
import sys
from pathlib import Path


def run_complete(run_dir):
    run_dir = Path(run_dir)
    exit_code_path = run_dir / "exit_code"
    if not exit_code_path.exists() or exit_code_path.read_text().strip() != "0":
        return False
    for name in ("activation.json", "metrics.json", "tokens.json", "summary.json"):
        p = run_dir / name
        if not p.exists() or not p.stat().st_size:
            return False
        try:
            json.loads(p.read_text())
        except json.JSONDecodeError:
            return False
    activation = json.loads((run_dir / "activation.json").read_text())
    return bool(activation.get("activation_ok"))


def judge_complete(judge_file):
    p = Path(judge_file)
    if not p.exists() or not p.stat().st_size:
        return False
    try:
        data = json.loads(p.read_text())
    except json.JSONDecodeError:
        return False
    return bool(data.get("vanilla")) and bool(data.get("claudia"))


def main():
    kind, path = sys.argv[1], sys.argv[2]
    ok = run_complete(path) if kind == "run" else judge_complete(path)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
