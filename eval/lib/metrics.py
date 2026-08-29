#!/usr/bin/env python3
"""Deterministic metrics for one eval run: LOC/files touched from git diff,
new dependencies introduced in any package.json, and the task's own
grep_checks. Stdlib only.

Usage: metrics.py <task-file> <repo-dir> [<base-ref>]

<base-ref> defaults to HEAD, correct for the synthetic-fixture corpus
(fixture committed once, model's changes are left uncommitted). The
italy-rs case study has the model commit its own work, moving HEAD, so
eval/integration.sh passes the pre-run branch-point SHA explicitly.
Prints a JSON object to stdout.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from frontmatter import parse  # noqa: E402


def git(repo, *args):
    out = subprocess.run(
        ["git", "-C", repo, *args], capture_output=True, text=True, check=False
    )
    return out.stdout


def loc_and_files(repo, base_ref="HEAD"):
    numstat = git(repo, "diff", "--numstat", base_ref)
    added = removed = files = 0
    for line in numstat.splitlines():
        if not line.strip():
            continue
        parts = line.split("\t")
        if len(parts) < 3:
            continue
        a, r, _ = parts[0], parts[1], parts[2]
        files += 1
        added += int(a) if a.isdigit() else 0
        removed += int(r) if r.isdigit() else 0
    return added, removed, files


def new_dependencies(repo, base_ref="HEAD"):
    changed = git(repo, "diff", "--name-only", base_ref).splitlines()
    new_deps = []
    for rel in changed:
        if Path(rel).name != "package.json":
            continue
        before_raw = git(repo, "show", f"{base_ref}:{rel}")
        after_path = Path(repo) / rel
        if not after_path.exists():
            continue
        try:
            before = json.loads(before_raw) if before_raw.strip() else {}
        except json.JSONDecodeError:
            before = {}
        try:
            after = json.loads(after_path.read_text())
        except json.JSONDecodeError:
            continue
        for section in ("dependencies", "devDependencies"):
            before_keys = set((before.get(section) or {}).keys())
            after_keys = set((after.get(section) or {}).keys())
            for dep in sorted(after_keys - before_keys):
                new_deps.append(f"{rel}:{section}:{dep}")
    return new_deps


def run_grep_checks(repo, task):
    results = {}
    for check in task.get("grep_checks", []):
        pattern = check.get("pattern", "")
        rel = check.get("file", "")
        expect = check.get("expect", "present")
        path = Path(repo) / rel
        found = False
        if path.exists():
            found = re.search(pattern, path.read_text(errors="replace")) is not None
        passed = found if expect == "present" else not found
        results[f"{rel}:{pattern}"] = passed
    return results


def main():
    task_file, repo = sys.argv[1], sys.argv[2]
    base_ref = sys.argv[3] if len(sys.argv) > 3 else "HEAD"
    task, _body = parse(task_file)
    added, removed, files = loc_and_files(repo, base_ref)
    out = {
        "loc_added": added,
        "loc_removed": removed,
        "files_touched": files,
        "new_dependencies": new_dependencies(repo, base_ref),
        "grep_checks": run_grep_checks(repo, task),
    }
    print(json.dumps(out, indent=2))


if __name__ == "__main__":
    main()
