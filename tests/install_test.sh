#!/bin/sh
# Smoke test for install.sh. Runs entirely inside a throwaway sandbox HOME
# with no inherited CLAUDE_CONFIG_DIR, so it can never touch a real account.
# Cleans up only the sandbox dir it created, nothing else.
set -eu

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

FAIL=0
assert_file() {
  [ -f "$1" ] || { echo "FAIL: expected file missing: $1"; FAIL=1; }
}
assert_no_file() {
  [ -f "$1" ] && { echo "FAIL: expected file absent but found: $1"; FAIL=1; }
  return 0
}

run_install() {
  # env -i: no inherited CLAUDE_CONFIG_DIR/HOME from the real session.
  env -i HOME="$SANDBOX" PATH="$PATH" sh "$REPO_DIR/install.sh" "$@"
}

echo "== test: single account (no other .claude* dirs) installs directly =="
mkdir -p "$SANDBOX/.claude"
run_install < /dev/null > /dev/null
assert_file "$SANDBOX/.claude/output-styles/claudia.md"
assert_file "$SANDBOX/.claude/agents/claudia.md"
rm -rf "$SANDBOX/.claude"

echo "== test: multiple accounts + non-interactive installs default only =="
mkdir -p "$SANDBOX/.claude" "$SANDBOX/.claude-work"
run_install < /dev/null > /dev/null
assert_file "$SANDBOX/.claude/output-styles/claudia.md"
assert_no_file "$SANDBOX/.claude-work/output-styles/claudia.md"
assert_no_file "$SANDBOX/.claude-work/CLAUDE.md"
rm -rf "$SANDBOX/.claude" "$SANDBOX/.claude-work"

echo "== test: --set-output-style writes outputStyle non-interactively =="
mkdir -p "$SANDBOX/.claude"
echo '{}' > "$SANDBOX/.claude/settings.json"
run_install --set-output-style < /dev/null > /dev/null
grep -q '"outputStyle": "claudia"' "$SANDBOX/.claude/settings.json" \
  || { echo "FAIL: outputStyle not set"; FAIL=1; }
rm -rf "$SANDBOX/.claude"

echo "== test: read guard is linked and registered, prompt or not =="
mkdir -p "$SANDBOX/.claude"
run_install < /dev/null > /dev/null
assert_file "$SANDBOX/.claude/hooks/read-guard.sh"
assert_file "$SANDBOX/.claude/hooks/read-guard.py"
assert_file "$SANDBOX/.claude/agents/bulk-reader.md"
# Registered even though the outputStyle prompt was declined.
grep -q 'read-guard.sh' "$SANDBOX/.claude/settings.json" \
  || { echo "FAIL: read guard not registered"; FAIL=1; }
count_hooks() {
  python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("hooks",{}).get(sys.argv[2],[]).__len__())' "$1" "$2"
}
[ "$(count_hooks "$SANDBOX/.claude/settings.json" PreToolUse)" = "1" ] \
  || { echo "FAIL: expected exactly one PreToolUse entry"; FAIL=1; }

echo "== test: session-boot hook is linked and registered =="
assert_file "$SANDBOX/.claude/hooks/session-boot.sh"
assert_file "$SANDBOX/.claude/hooks/session-boot.py"
grep -q 'session-boot.sh' "$SANDBOX/.claude/settings.json" \
  || { echo "FAIL: session-boot hook not registered"; FAIL=1; }
[ "$(count_hooks "$SANDBOX/.claude/settings.json" SessionStart)" = "1" ] \
  || { echo "FAIL: expected exactly one SessionStart entry"; FAIL=1; }

echo "== test: re-install does not stack a second registration =="
run_install < /dev/null > /dev/null
[ "$(count_hooks "$SANDBOX/.claude/settings.json" PreToolUse)" = "1" ] \
  || { echo "FAIL: re-install stacked a duplicate read-guard entry"; FAIL=1; }
[ "$(count_hooks "$SANDBOX/.claude/settings.json" SessionStart)" = "1" ] \
  || { echo "FAIL: re-install stacked a duplicate session-boot entry"; FAIL=1; }
rm -rf "$SANDBOX/.claude"

echo "== test: unterminated claudia marker block aborts instead of truncating =="
mkdir -p "$SANDBOX/.claude"
printf 'kept before\n<!-- claudia:start -->\nstale import\nkept after\n' > "$SANDBOX/.claude/CLAUDE.md"
run_install < /dev/null > /dev/null 2>&1 && { echo "FAIL: install did not abort on unterminated marker"; FAIL=1; }
grep -q "kept after" "$SANDBOX/.claude/CLAUDE.md" \
  || { echo "FAIL: content after an unterminated marker was silently dropped"; FAIL=1; }
rm -rf "$SANDBOX/.claude"

echo "== test: edited symlink + existing .bak is refused, not deleted =="
mkdir -p "$SANDBOX/.claude"
run_install < /dev/null > /dev/null
rm "$SANDBOX/.claude/agents/claudia.md"
printf 'edited local content\n' > "$SANDBOX/.claude/agents/claudia.md"
printf 'earlier backup\n' > "$SANDBOX/.claude/agents/claudia.md.bak"
run_install < /dev/null > /dev/null 2>&1 && { echo "FAIL: install did not abort on backup conflict"; FAIL=1; }
grep -q "edited local content" "$SANDBOX/.claude/agents/claudia.md" \
  || { echo "FAIL: edited content was deleted instead of left alone"; FAIL=1; }
rm -rf "$SANDBOX/.claude"

echo "== test: malformed settings.json is left untouched =="
mkdir -p "$SANDBOX/.claude"
printf '{ not json' > "$SANDBOX/.claude/settings.json"
run_install < /dev/null > /dev/null 2>&1
[ "$(cat "$SANDBOX/.claude/settings.json")" = "{ not json" ] \
  || { echo "FAIL: malformed settings.json was rewritten"; FAIL=1; }
# Files still land even when settings.json can't be edited.
assert_file "$SANDBOX/.claude/hooks/read-guard.sh"
rm -rf "$SANDBOX/.claude"

if [ "$FAIL" = "0" ]; then
  echo "PASS"
else
  echo "FAIL"
  exit 1
fi
