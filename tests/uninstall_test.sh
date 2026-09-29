#!/bin/sh
# Smoke test for uninstall.sh. Runs entirely inside a throwaway sandbox HOME
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
  env -i HOME="$SANDBOX" PATH="$PATH" sh "$REPO_DIR/install.sh" "$@"
}
run_uninstall() {
  env -i HOME="$SANDBOX" PATH="$PATH" sh "$REPO_DIR/uninstall.sh" "$@"
}

echo "== test: single account uninstall removes files and restores .bak =="
mkdir -p "$SANDBOX/.claude"
printf 'pre-existing content\n' > "$SANDBOX/.claude/CLAUDE.md"
run_install < /dev/null > /dev/null
assert_file "$SANDBOX/.claude/output-styles/claudia.md"
run_uninstall < /dev/null > /dev/null
assert_no_file "$SANDBOX/.claude/output-styles/claudia.md"
assert_no_file "$SANDBOX/.claude/agents/claudia.md"
grep -q "pre-existing content" "$SANDBOX/.claude/CLAUDE.md" \
  || { echo "FAIL: original CLAUDE.md content lost"; FAIL=1; }
grep -q "claudia:start" "$SANDBOX/.claude/CLAUDE.md" \
  && { echo "FAIL: claudia block still present after uninstall"; FAIL=1; }
rm -rf "$SANDBOX/.claude"

echo "== test: multiple accounts + non-interactive uninstalls default only =="
mkdir -p "$SANDBOX/.claude" "$SANDBOX/.claude-work"
# Non-interactive install only touches the default; install into each dir
# explicitly (default, then via CLAUDE_CONFIG_DIR) so both are populated.
run_install < /dev/null > /dev/null
env -i HOME="$SANDBOX" PATH="$PATH" CLAUDE_CONFIG_DIR="$SANDBOX/.claude-work" \
  sh "$REPO_DIR/install.sh" < /dev/null > /dev/null
assert_file "$SANDBOX/.claude/output-styles/claudia.md"
assert_file "$SANDBOX/.claude-work/output-styles/claudia.md"

run_uninstall < /dev/null > /dev/null
assert_no_file "$SANDBOX/.claude/output-styles/claudia.md"
assert_file "$SANDBOX/.claude-work/output-styles/claudia.md"
rm -rf "$SANDBOX/.claude" "$SANDBOX/.claude-work"

echo "== test: uninstall strips claudia hooks and keeps the user's own =="
mkdir -p "$SANDBOX/.claude"
cat > "$SANDBOX/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{"type": "command", "command": "/opt/mine/audit.sh"}]
      }
    ],
    "Stop": [
      {
        "hooks": [{"type": "command", "command": "/opt/mine/done.sh"}]
      }
    ]
  }
}
JSON
cp "$SANDBOX/.claude/settings.json" "$SANDBOX/before.json"
run_install < /dev/null > /dev/null
grep -q 'read-guard.sh' "$SANDBOX/.claude/settings.json" \
  || { echo "FAIL: read guard not registered"; FAIL=1; }
grep -q 'session-boot.sh' "$SANDBOX/.claude/settings.json" \
  || { echo "FAIL: session-boot hook not registered"; FAIL=1; }
run_uninstall < /dev/null > /dev/null
assert_no_file "$SANDBOX/.claude/hooks/read-guard.sh"
assert_no_file "$SANDBOX/.claude/hooks/session-boot.sh"
assert_no_file "$SANDBOX/.claude/agents/bulk-reader.md"
grep -q 'read-guard.sh' "$SANDBOX/.claude/settings.json" \
  && { echo "FAIL: claudia read guard survived uninstall"; FAIL=1; }
grep -q 'session-boot.sh' "$SANDBOX/.claude/settings.json" \
  && { echo "FAIL: claudia session-boot hook survived uninstall"; FAIL=1; }
# Semantic round trip: the user's own hooks come back exactly as they were.
python3 -c 'import json,sys; a=json.load(open(sys.argv[1])); b=json.load(open(sys.argv[2])); sys.exit(0 if a==b else 1)' \
  "$SANDBOX/before.json" "$SANDBOX/.claude/settings.json" \
  || { echo "FAIL: settings.json not restored to its pre-install state"; FAIL=1; }
rm -rf "$SANDBOX/.claude" "$SANDBOX/before.json"

echo "== test: uninstall leaves a symlink an editor replaced with a real file alone =="
mkdir -p "$SANDBOX/.claude"
run_install < /dev/null > /dev/null
rm "$SANDBOX/.claude/agents/claudia.md"
printf 'edited local content\n' > "$SANDBOX/.claude/agents/claudia.md"
run_uninstall < /dev/null > /dev/null
grep -q "edited local content" "$SANDBOX/.claude/agents/claudia.md" \
  || { echo "FAIL: uninstall deleted a replaced symlink's content instead of leaving it"; FAIL=1; }
rm -rf "$SANDBOX/.claude"

echo "== test: uninstall never strips a foreign hook sharing a claudia basename =="
mkdir -p "$SANDBOX/.claude" "$SANDBOX/elsewhere/hooks"
printf '#!/bin/sh\n' > "$SANDBOX/elsewhere/hooks/read-guard.sh"
cat > "$SANDBOX/.claude/settings.json" <<JSON
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{"type": "command", "command": "$SANDBOX/elsewhere/hooks/read-guard.sh"}]
      }
    ]
  }
}
JSON
run_install < /dev/null > /dev/null
run_uninstall < /dev/null > /dev/null
grep -q "$SANDBOX/elsewhere/hooks/read-guard.sh" "$SANDBOX/.claude/settings.json" \
  || { echo "FAIL: uninstall stripped a foreign hook with a matching basename"; FAIL=1; }
rm -rf "$SANDBOX/.claude" "$SANDBOX/elsewhere"

echo "== test: unterminated claudia marker block is left untouched on uninstall =="
mkdir -p "$SANDBOX/.claude"
printf 'kept before\n<!-- claudia:start -->\nstale import\nkept after\n' > "$SANDBOX/.claude/CLAUDE.md"
run_uninstall < /dev/null > /dev/null 2>&1 || true
grep -q "kept after" "$SANDBOX/.claude/CLAUDE.md" \
  || { echo "FAIL: content after an unterminated marker was silently dropped"; FAIL=1; }
rm -rf "$SANDBOX/.claude"

if [ "$FAIL" = "0" ]; then
  echo "PASS"
else
  echo "FAIL"
  exit 1
fi
