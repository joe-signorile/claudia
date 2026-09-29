"""PreToolUse guard body. Invoked by read-guard.sh with the threshold as argv[1]
and the hook event on stdin. Prints a deny decision or nothing."""

import json
import os
import re
import shlex
import sys

PAGERS = ("cat", "head", "tail", "less", "more")
AMBIGUOUS = re.compile(r"[|><" + chr(96) + r"]|\$\(")
PAGER_CALL = re.compile(r"\s*(" + "|".join(PAGERS) + r")\s+(.*)", re.S)


def allow():
    sys.exit(0)


def deny(limit, path, lines, how):
    reason = (
        "{} is {:,} lines, over the {}-line read guard.\n"
        "Spawn the bulk-reader agent (model: haiku) with your question and this "
        "path instead of pulling it inline.\n"
        "If you need exact text to edit, {} for just the region you need.\n"
        "Set CLAUDIA_READ_GUARD_LINES=0 to disable this guard."
    ).format(path, lines, limit, how)
    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": reason,
            }
        },
        sys.stdout,
    )
    sys.exit(0)


def line_count(path, cwd):
    """Lines in path, or None if it should not be judged (missing, binary,
    unreadable). None always means allow."""
    try:
        full = path if os.path.isabs(path) else os.path.join(cwd, path)
        if not os.path.isfile(full):
            return None
        total = 0
        with open(full, "rb") as fh:
            for chunk in iter(lambda: fh.read(65536), b""):
                if b"\0" in chunk:
                    return None
                total += chunk.count(b"\n")
        return total
    except OSError:
        return None


def main():
    try:
        limit = int(sys.argv[1])
    except (IndexError, ValueError):
        allow()

    try:
        event = json.load(sys.stdin)
        tool = event.get("tool_name")
        args = event.get("tool_input") or {}
        cwd = event.get("cwd") or os.getcwd()
    except Exception:
        allow()

    if tool == "Read":
        # A bounded read is already the behaviour the guard is asking for. This
        # exemption is load-bearing: it keeps large files editable, and it is
        # what stops bulk-reader's own reads from tripping the guard that
        # spawned it.
        if args.get("offset") is not None or args.get("limit") is not None:
            allow()
        path = args.get("file_path")
        if not path:
            allow()
        lines = line_count(path, cwd)
        if lines is None or lines <= limit:
            allow()
        deny(limit, path, lines, "re-read with offset/limit")

    if tool == "Bash":
        command = args.get("command") or ""
        # claudia: naive arg parse - upgrade if pipelines start leaking large
        # reads. A false positive breaks real work; a missed bypass costs
        # tokens, so anything with shell plumbing in it is allowed through.
        if AMBIGUOUS.search(command):
            allow()
        match = PAGER_CALL.match(command)
        if not match:
            allow()
        pager, rest = match.group(1), match.group(2)
        try:
            words = shlex.split(rest)
        except ValueError:
            allow()
        # head/tail are bounded by default (10 lines), and tail -f is a
        # stream, not a whole-file read - same exemption as offset.
        if pager in ("head", "tail"):
            allow()
        target = next((w for w in words if not w.startswith("-")), None)
        if not target:
            allow()
        lines = line_count(target, cwd)
        if lines is None or lines <= limit:
            allow()
        deny(
            limit,
            target,
            lines,
            "use {} with a line count, or Read with offset/limit".format(pager),
        )

    allow()


main()
