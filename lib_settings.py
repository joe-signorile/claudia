#!/usr/bin/env python3
"""settings.json edits for install.sh / uninstall.sh. Repo-local tooling, never
copied into ~/.claude/.

Usage:
  lib_settings.py style     <settings.json>
  lib_settings.py hooks-on  <settings.json> <hook command path>
  lib_settings.py hooks-off <settings.json>
  lib_settings.py hooks-clear <settings.json>   (drop the whole hooks key; eval sandbox)

Malformed JSON is never rewritten: the file is left untouched and the caller
told to fix it by hand.
"""

import json
import os
import sys

HOOKS = {
    "read-guard.sh": {"event": "PreToolUse", "matcher": "Read|Bash"},
    "session-boot.sh": {"event": "SessionStart", "matcher": "startup"},
}


def load(path):
    if not os.path.exists(path):
        return {}
    text = open(path).read()
    if not text.strip():
        return {}
    try:
        return json.loads(text)
    except json.JSONDecodeError as exc:
        sys.stderr.write("{} is not valid JSON ({}); leaving it untouched.\n".format(path, exc))
        sys.exit(1)


# claudia: plain truncate+write, no temp-file+rename — upgrade if a killed
# process/full disk is ever observed to leave settings.json truncated.
def save(path, data):
    with open(path, "w") as fh:
        fh.write(json.dumps(data, indent=2) + "\n")


def owned(hook, settings_dir, names=None):
    """True for a hook entry claudia installed into this settings.json's own
    config dir. Anchored on the command living in *this dir's* hooks/
    directory (not a bare "/hooks/" substring) so a user's unrelated hook
    script - even one that happens to share a basename and sit under some
    other "hooks" directory of its own - is never touched. `names` narrows
    which claudia hooks count as owned (default: all of them) - hooks-on
    uses this to strip only its own prior registration, not a sibling
    hook's, since install.sh calls hooks-on once per hook file."""
    command = hook.get("command", "") if isinstance(hook, dict) else ""
    if not command:
        return False
    base = os.path.basename(command)
    if base not in (names if names is not None else HOOKS):
        return False
    return os.path.dirname(os.path.abspath(command)) == os.path.join(settings_dir, "hooks")


def strip(data, settings_dir, names=None):
    """Remove claudia-owned hooks from every event, pruning anything left
    empty."""
    hooks = data.get("hooks")
    if not isinstance(hooks, dict):
        return data
    for event in list(hooks.keys()):
        entries = hooks.get(event)
        if not isinstance(entries, list):
            continue
        kept = []
        for entry in entries:
            if not isinstance(entry, dict):
                kept.append(entry)
                continue
            inner = entry.get("hooks")
            if not isinstance(inner, list):
                kept.append(entry)
                continue
            remaining = [h for h in inner if not owned(h, settings_dir, names)]
            if not remaining:
                continue
            entry["hooks"] = remaining
            kept.append(entry)
        if kept:
            hooks[event] = kept
        else:
            hooks.pop(event, None)
    if not hooks:
        data.pop("hooks", None)
    return data


def main():
    if len(sys.argv) < 3:
        sys.stderr.write(__doc__)
        sys.exit(2)
    op, path = sys.argv[1], sys.argv[2]
    data = load(path)
    settings_dir = os.path.dirname(os.path.abspath(path))

    if op == "style":
        data["outputStyle"] = "claudia"
    elif op == "hooks-on":
        command = sys.argv[3]
        name = os.path.basename(command)
        cfg = HOOKS.get(name)
        if cfg is None:
            sys.stderr.write("unknown hook: {}\n".format(name))
            sys.exit(2)
        # Strip this hook's own prior registration first, then add: re-running
        # after the repo moves rewrites the stale path instead of stacking a
        # second registration. Scoped to `name` so registering one claudia
        # hook never strips another's already-installed entry.
        data = strip(data, settings_dir, names={name})
        entry = {"hooks": [{"type": "command", "command": command}]}
        if cfg.get("matcher"):
            entry["matcher"] = cfg["matcher"]
        data.setdefault("hooks", {}).setdefault(cfg["event"], []).append(entry)
    elif op == "hooks-off":
        data = strip(data, settings_dir)
    elif op == "hooks-clear":
        data.pop("hooks", None)
    else:
        sys.stderr.write("unknown op: {}\n".format(op))
        sys.exit(2)

    save(path, data)


main()
