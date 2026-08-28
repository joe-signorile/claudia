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

if [ "$FAIL" = "0" ]; then
  echo "PASS"
else
  echo "FAIL"
  exit 1
fi
