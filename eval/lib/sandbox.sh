#!/bin/sh
# Sandbox lifecycle for one eval run: a throwaway git repo plus an isolated
# Claude config dir, so a run can never touch the operator's real ~/.claude
# or working tree. Mirrors the mktemp -d + isolation idiom in
# tests/install_test.sh.
set -eu

# Sourced, so $0 is the caller's script, not this file; take REPO_DIR from it.
SANDBOX_LIB_REPO_DIR="${REPO_DIR:?sandbox.sh: caller must set REPO_DIR}"

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
    "$dir/home/.claude/output-styles" "$dir/home/.claude/hooks"
  # settings.json is copied wholesale for auth, so it carries the operator's
  # own hook registrations, whose paths point at the real config dir (so
  # hooks-off's ownership check would not match the sandbox). Drop the key;
  # the claudia arm re-registers via install.sh. Failure is loud: a leaked
  # guard silently voids the control arm.
  if [ -f "$dir/home/.claude/settings.json" ]; then
    python3 "$SANDBOX_LIB_REPO_DIR/lib_settings.py" hooks-clear \
      "$dir/home/.claude/settings.json" >/dev/null
  fi
  printf '%s\n' "$dir"
}

cleanup_sandbox() {
  [ -n "${1:-}" ] && rm -rf "$1"
}
