#!/bin/sh
# Sandbox lifecycle for one eval run: a throwaway git repo plus an isolated
# Claude config dir, so a run can never touch the operator's real ~/.claude
# or working tree. Mirrors the mktemp -d + isolation idiom in
# tests/install_test.sh.
set -eu

# Config dir to seed auth/session state from (NOT behavior config — see
# strip step below). Best-effort: if `claude`'s credentials live somewhere
# other than this discovered dir, runs will fail to authenticate and
# `./run.sh --smoke` will surface that immediately.
: "${EVAL_BASE_CONFIG_DIR:=${CLAUDE_CONFIG_DIR:-$HOME/.claude}}"

# make_sandbox: creates a fresh sandbox dir and prints its path.
# Layout: $dir/home/.claude (the config dir), $dir/repo (the throwaway repo).
make_sandbox() {
  dir="$(mktemp -d)"
  mkdir -p "$dir/home/.claude" "$dir/repo"
  if [ -d "$EVAL_BASE_CONFIG_DIR" ]; then
    cp -R "$EVAL_BASE_CONFIG_DIR/." "$dir/home/.claude/" 2>/dev/null || true
  fi
  # Strip anything that carries behavior/instructions regardless of arm.
  # Each arm re-adds only what it needs: nothing for vanilla, a real
  # install.sh run for claudia. Neither arm should inherit the operator's
  # own personal CLAUDE.md/skills/agents/output-style.
  rm -rf "$dir/home/.claude/CLAUDE.md" "$dir/home/.claude/CLAUDE.md.bak" \
    "$dir/home/.claude/skills" "$dir/home/.claude/agents" \
    "$dir/home/.claude/output-styles"
  printf '%s\n' "$dir"
}

cleanup_sandbox() {
  [ -n "${1:-}" ] && rm -rf "$1"
}
