#!/bin/sh
# Removes monkey-boy from one or more Claude Code config dirs. Safe to re-run.
# Leaves settings.json (outputStyle) untouched — change that via /config.
set -eu

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
MARKER_START="<!-- monkey-boy:start -->"
MARKER_END="<!-- monkey-boy:end -->"

. "$REPO_DIR/lib_dirs.sh"

CANDIDATES_FILE="$(mktemp)"
SELECTED_FILE="$(mktemp)"
trap 'rm -f "$CANDIDATES_FILE" "$SELECTED_FILE"' EXIT

select_dirs "Uninstall from"

# Remove an installed file; if install.sh backed up a pre-existing one to
# .bak, restore it so uninstall is symmetric with install.
remove_and_restore() {
  dest="$1"
  rm -f "$dest"
  if [ -f "$dest.bak" ]; then
    mv "$dest.bak" "$dest"
    echo "Restored $dest from $dest.bak"
  fi
}

uninstall_one() {
  CLAUDE_DIR="$1"
  echo ""
  echo "== $CLAUDE_DIR =="

  remove_and_restore "$CLAUDE_DIR/output-styles/monkey-boy.md"
  remove_and_restore "$CLAUDE_DIR/skills/fresh-work/SKILL.md"
  remove_and_restore "$CLAUDE_DIR/skills/monkey-boy-debt/SKILL.md"
  remove_and_restore "$CLAUDE_DIR/skills/doc-router/SKILL.md"
  remove_and_restore "$CLAUDE_DIR/agents/monkey-boy.md"
  rmdir "$CLAUDE_DIR/skills/fresh-work" 2>/dev/null || true
  rmdir "$CLAUDE_DIR/skills/monkey-boy-debt" 2>/dev/null || true
  rmdir "$CLAUDE_DIR/skills/doc-router" 2>/dev/null || true

  CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
  if [ -f "$CLAUDE_MD" ] && grep -qF "$MARKER_START" "$CLAUDE_MD"; then
    # Remove the marker-fenced block, and drop the blank line install.sh
    # prepended before it (buffered blanks are discarded when the start marker
    # follows, flushed otherwise so blanks inside real content are preserved).
    awk -v s="$MARKER_START" -v e="$MARKER_END" '
      skip { if (index($0, e)) skip = 0; next }
      index($0, s) { skip = 1; n = 0; next }
      /^[[:space:]]*$/ { buf[++n] = $0; next }
      { for (i = 1; i <= n; i++) print buf[i]; n = 0; print }
      END { for (i = 1; i <= n; i++) print buf[i] }
    ' "$CLAUDE_MD" > "$CLAUDE_MD.tmp" && mv "$CLAUDE_MD.tmp" "$CLAUDE_MD"
    echo "Removed monkey-boy block from $CLAUDE_MD"
  fi

  echo "Uninstalled monkey-boy files from $CLAUDE_DIR."
}

while IFS= read -r dir; do
  uninstall_one "$dir"
done < "$SELECTED_FILE"

echo ""
echo "If outputStyle is still set to monkey-boy in settings.json, change it via /config."
