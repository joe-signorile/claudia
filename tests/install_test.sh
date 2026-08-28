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

if [ "$FAIL" = "0" ]; then
  echo "PASS"
else
  echo "FAIL"
  exit 1
fi
