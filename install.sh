#!/bin/sh
# Installs monkey-boy into one or more Claude Code config dirs. Safe to re-run.
# Pass --set-output-style to write outputStyle into settings.json
# non-interactively (skips the per-install prompt) for every selected dir.
set -eu

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
MARKER_START="<!-- monkey-boy:start -->"
MARKER_END="<!-- monkey-boy:end -->"
FORCE_OUTPUT_STYLE=0
[ "${1:-}" = "--set-output-style" ] && FORCE_OUTPUT_STYLE=1

. "$REPO_DIR/lib_dirs.sh"

CANDIDATES_FILE="$(mktemp)"
SELECTED_FILE="$(mktemp)"
trap 'rm -f "$CANDIDATES_FILE" "$SELECTED_FILE"' EXIT

select_dirs "Install into"

# Copy src -> dest, backing up an existing dest that differs to dest.bak.
backup_and_copy() {
  src="$1"; dest="$2"
  # Back up a differing existing dest, but only once: don't clobber a backup
  # from an earlier install with a copy of our own file on re-runs.
  if [ -f "$dest" ] && ! cmp -s "$src" "$dest" && [ ! -f "$dest.bak" ]; then
    cp "$dest" "$dest.bak"
    echo "Backed up existing $dest -> $dest.bak"
  fi
  cp "$src" "$dest"
}

set_output_style() {
  settings="$1/settings.json"
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$settings" <<'PY'
import json, sys, pathlib
path = pathlib.Path(sys.argv[1])
text = path.read_text() if path.exists() else ""
try:
    data = json.loads(text) if text.strip() else {}
except json.JSONDecodeError as e:
    sys.stderr.write(f"{path} is not valid JSON ({e}); leaving it untouched.\n")
    sys.stderr.write("Set Output style -> monkey-boy via /config instead.\n")
    sys.exit(1)
data["outputStyle"] = "monkey-boy"
path.write_text(json.dumps(data, indent=2) + "\n")
PY
    echo "Set outputStyle: monkey-boy in $settings"
  else
    echo "python3 not found, can't set outputStyle non-interactively." >&2
    echo "Run /config in Claude Code and select Output style -> monkey-boy instead." >&2
    return 1
  fi
}

install_one() {
  CLAUDE_DIR="$1"
  echo ""
  echo "== $CLAUDE_DIR =="

  mkdir -p "$CLAUDE_DIR/output-styles" "$CLAUDE_DIR/skills/fresh-work" \
    "$CLAUDE_DIR/skills/monkey-boy-debt" "$CLAUDE_DIR/skills/doc-router" \
    "$CLAUDE_DIR/agents"

  backup_and_copy "$REPO_DIR/output-styles/monkey-boy.md" "$CLAUDE_DIR/output-styles/monkey-boy.md"
  backup_and_copy "$REPO_DIR/skills/fresh-work/SKILL.md" "$CLAUDE_DIR/skills/fresh-work/SKILL.md"
  backup_and_copy "$REPO_DIR/skills/monkey-boy-debt/SKILL.md" "$CLAUDE_DIR/skills/monkey-boy-debt/SKILL.md"
  backup_and_copy "$REPO_DIR/skills/doc-router/SKILL.md" "$CLAUDE_DIR/skills/doc-router/SKILL.md"
  backup_and_copy "$REPO_DIR/agents/monkey-boy.md" "$CLAUDE_DIR/agents/monkey-boy.md"

  CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
  touch "$CLAUDE_MD"
  if ! grep -qF "$MARKER_START" "$CLAUDE_MD" && ! grep -qF "$MARKER_END" "$CLAUDE_MD"; then
    printf '\n' >> "$CLAUDE_MD"
    cat "$REPO_DIR/CLAUDE.md.snippet" >> "$CLAUDE_MD"
    echo "Appended monkey-boy block to $CLAUDE_MD"
  else
    echo "monkey-boy block already present in $CLAUDE_MD, skipping"
  fi

  echo "Installed output-style, fresh-work + monkey-boy-debt + doc-router"
  echo "skills, and the monkey-boy agent."

  do_set=0
  if [ "$FORCE_OUTPUT_STYLE" = "1" ]; then
    do_set=1
  elif [ -t 0 ]; then
    printf "Set Output style -> monkey-boy in %s/settings.json now? [y/N]: " "$CLAUDE_DIR"
    read -r ans
    case "$ans" in y|Y|yes|YES) do_set=1 ;; esac
  fi

  if [ "$do_set" = "1" ]; then
    set_output_style "$CLAUDE_DIR"
  else
    echo "To activate the voice/ladder, run /config in Claude Code (with"
    echo "CLAUDE_CONFIG_DIR=$CLAUDE_DIR if applicable) and select Output style -> monkey-boy."
  fi
}

while IFS= read -r dir; do
  install_one "$dir"
done < "$SELECTED_FILE"
