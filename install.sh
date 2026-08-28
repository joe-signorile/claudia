#!/bin/sh
# Installs claudia into one or more Claude Code config dirs. Safe to re-run.
# Pass --set-output-style to write outputStyle into settings.json
# non-interactively (skips the per-install prompt) for every selected dir.
set -eu

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
MARKER_START="<!-- claudia:start -->"
MARKER_END="<!-- claudia:end -->"
FORCE_OUTPUT_STYLE=0
[ "${1:-}" = "--set-output-style" ] && FORCE_OUTPUT_STYLE=1

. "$REPO_DIR/lib_dirs.sh"

CANDIDATES_FILE="$(mktemp)"
SELECTED_FILE="$(mktemp)"
trap 'rm -f "$CANDIDATES_FILE" "$SELECTED_FILE"' EXIT

select_dirs "Install into"

# Symlink dest -> src, backing up a pre-existing non-symlink dest once.
link_and_backup() {
  src="$1"; dest="$2"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    return 0
  fi
  if [ -e "$dest" ] && [ ! -L "$dest" ] && [ ! -f "$dest.bak" ]; then
    mv "$dest" "$dest.bak"
    echo "Backed up existing $dest -> $dest.bak"
  else
    rm -f "$dest"
  fi
  ln -s "$src" "$dest"
  echo "Linked $dest -> $src"
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
    sys.stderr.write("Set Output style -> claudia via /config instead.\n")
    sys.exit(1)
data["outputStyle"] = "claudia"
path.write_text(json.dumps(data, indent=2) + "\n")
PY
    echo "Set outputStyle: claudia in $settings"
  else
    echo "python3 not found, can't set outputStyle non-interactively." >&2
    echo "Run /config in Claude Code and select Output style -> claudia instead." >&2
    return 1
  fi
}

install_one() {
  CLAUDE_DIR="$1"
  echo ""
  echo "== $CLAUDE_DIR =="

  mkdir -p "$CLAUDE_DIR/output-styles" "$CLAUDE_DIR/skills/fresh-work" \
    "$CLAUDE_DIR/skills/claudia-debt" "$CLAUDE_DIR/skills/doc-router" \
    "$CLAUDE_DIR/agents"

  link_and_backup "$REPO_DIR/output-styles/claudia.md" "$CLAUDE_DIR/output-styles/claudia.md"
  link_and_backup "$REPO_DIR/skills/fresh-work/SKILL.md" "$CLAUDE_DIR/skills/fresh-work/SKILL.md"
  link_and_backup "$REPO_DIR/skills/claudia-debt/SKILL.md" "$CLAUDE_DIR/skills/claudia-debt/SKILL.md"
  link_and_backup "$REPO_DIR/skills/doc-router/SKILL.md" "$CLAUDE_DIR/skills/doc-router/SKILL.md"
  link_and_backup "$REPO_DIR/agents/claudia.md" "$CLAUDE_DIR/agents/claudia.md"

  # CLAUDE.md can't be symlinked whole (it holds the user's own content too),
  # so the fenced block holds a single @import line instead of a pasted copy.
  CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
  touch "$CLAUDE_MD"
  IMPORT_LINE="@$REPO_DIR/CLAUDE.md.snippet"
  if grep -qF "$MARKER_START" "$CLAUDE_MD" && grep -qF "$MARKER_END" "$CLAUDE_MD"; then
    awk -v s="$MARKER_START" -v e="$MARKER_END" -v imp="$IMPORT_LINE" '
      index($0, s) { print; print imp; skip = 1; next }
      skip && index($0, e) { print; skip = 0; next }
      skip { next }
      { print }
    ' "$CLAUDE_MD" > "$CLAUDE_MD.tmp" && mv "$CLAUDE_MD.tmp" "$CLAUDE_MD"
    echo "claudia block in $CLAUDE_MD now @imports the repo"
  else
    printf '\n%s\n%s\n%s\n' "$MARKER_START" "$IMPORT_LINE" "$MARKER_END" >> "$CLAUDE_MD"
    echo "Appended claudia @import block to $CLAUDE_MD"
  fi

  echo "Linked output-style, fresh-work + claudia-debt + doc-router"
  echo "skills, and the claudia agent straight to the repo."

  do_set=0
  if [ "$FORCE_OUTPUT_STYLE" = "1" ]; then
    do_set=1
  elif [ -t 0 ]; then
    printf "Set Output style -> claudia in %s/settings.json now? [y/N]: " "$CLAUDE_DIR"
    read -r ans
    case "$ans" in y|Y|yes|YES) do_set=1 ;; esac
  fi

  if [ "$do_set" = "1" ]; then
    set_output_style "$CLAUDE_DIR"
  else
    echo "To activate the voice/ladder, run /config in Claude Code (with"
    echo "CLAUDE_CONFIG_DIR=$CLAUDE_DIR if applicable) and select Output style -> claudia."
  fi
}

while IFS= read -r dir; do
  install_one "$dir"
done < "$SELECTED_FILE"
