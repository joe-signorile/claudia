#!/bin/sh
# lib_settings.py registration/prune behaviour, the eval sandbox strip, and
# the bulk-reader frontmatter. Sandboxed temp dirs only.
set -eu

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LIB="$REPO_DIR/lib_settings.py"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

FAIL=0
fail() { echo "FAIL: $1"; FAIL=1; }
# py <settings.json> <python expr over d>: exit 0 iff the expr is truthy
py() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if eval(sys.argv[2]) else 1)' "$1" "$2"; }

on() { python3 "$LIB" hooks-on "$1/settings.json" "$1/hooks/$2"; }

echo "== hooks-on registers the right event and matcher =="
A="$SANDBOX/a"; mkdir -p "$A"
on "$A" read-guard.sh
on "$A" session-boot.sh
py "$A/settings.json" 'd["hooks"]["PreToolUse"][0]["matcher"]=="Read|Bash"' || fail "PreToolUse matcher"
py "$A/settings.json" 'd["hooks"]["SessionStart"][0]["matcher"]=="startup"' || fail "SessionStart matcher"
py "$A/settings.json" 'len(d["hooks"]["PreToolUse"])==1 and len(d["hooks"]["SessionStart"])==1' || fail "one registration each"
on "$A" read-guard.sh
py "$A/settings.json" 'len(d["hooks"]["PreToolUse"])==1' || fail "re-run stacked a duplicate"

echo "== hooks-on self-heals after a repo move =="
B="$SANDBOX/b"; mkdir -p "$B"
python3 - "$B" <<'PY'
import json, sys
b = sys.argv[1]
json.dump({"hooks": {"PreToolUse": [{"matcher": "Read|Bash", "hooks": [
    {"type": "command", "command": "/old/repo/hooks/read-guard.sh"}]}]}},
    open(b + "/settings.json", "w"))
PY
# A stale path outside <dir>/hooks is not owned (by design); the same dir's
# own stale entry is what gets rewritten. Simulate: registered here, re-run.
on "$B" read-guard.sh
on "$B" read-guard.sh
py "$B/settings.json" 'sum(1 for e in d["hooks"]["PreToolUse"] for h in e["hooks"] if h["command"].startswith("'"$B"'/hooks/"))==1' || fail "own entry not idempotent"

echo "== hooks-off prunes the hooks key =="
python3 "$LIB" hooks-off "$A/settings.json"
py "$A/settings.json" '"hooks" not in d' || fail "hooks key not pruned"
C="$SANDBOX/c"; mkdir -p "$C"
python3 - "$C" <<'PY'
import json, sys
c = sys.argv[1]
json.dump({"hooks": {"PreToolUse": [{"hooks": [{"type": "command", "command": "/mine/own.sh"}]}]}},
          open(c + "/settings.json", "w"))
PY
on "$C" read-guard.sh
python3 "$LIB" hooks-off "$C/settings.json"
py "$C/settings.json" 'd["hooks"]["PreToolUse"][0]["hooks"][0]["command"]=="/mine/own.sh" and len(d["hooks"]["PreToolUse"])==1' || fail "user hook not preserved"

echo "== eval sandbox strips inherited hooks, claudia arm registers once =="
REAL="$SANDBOX/real"; mkdir -p "$REAL/hooks"
on "$REAL" read-guard.sh
on "$REAL" session-boot.sh
py "$REAL/settings.json" '"hooks" in d' || fail "fixture setup"
out="$(REPO_DIR="$REPO_DIR" EVAL_BASE_CONFIG_DIR="$REAL" sh -c '. "$REPO_DIR/eval/lib/sandbox.sh"; make_sandbox')"
py "$out/home/.claude/settings.json" '"hooks" not in d' || fail "vanilla sandbox kept hooks key"
SBX="$out/home/.claude"
on "$SBX" read-guard.sh
on "$SBX" session-boot.sh
py "$SBX/settings.json" 'len(d["hooks"]["PreToolUse"])==1 and len(d["hooks"]["SessionStart"])==1' || fail "claudia arm registration count"
rm -rf "$out"

echo "== bulk-reader frontmatter =="
f="$REPO_DIR/agents/bulk-reader.md"
grep -qx 'model: haiku' "$f" || fail "bulk-reader model"
grep -qx 'tools: Read, Grep, Glob' "$f" || fail "bulk-reader tools"

if [ "$FAIL" = "0" ]; then echo "PASS"; else echo "FAIL"; exit 1; fi
