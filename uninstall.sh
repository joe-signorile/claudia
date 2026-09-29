#!/bin/sh
# Removes claudia from one or more Claude Code config dirs. Safe to re-run.
# Strips the claudia-owned hooks from settings.json; leaves
# outputStyle and any hooks claudia didn't install alone.
set -eu

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
MARKER_START="<!-- claudia:start -->"
MARKER_END="<!-- claudia:end -->"

. "$REPO_DIR/lib_dirs.sh"

CANDIDATES_FILE="$(mktemp)"
SELECTED_FILE="$(mktemp)"
trap 'rm -f "$CANDIDATES_FILE" "$SELECTED_FILE"' EXIT

select_dirs "Uninstall from"

# Remove an installed file, but only if it's still claudia's own symlink
# (src -> dest) — a symlink an editor replaced with a real file, or a dest
# claudia never actually linked, is left untouched rather than deleted. If
# install.sh backed up a pre-existing file to .bak, restore it so uninstall
# is symmetric with install.
remove_and_restore() {
  src="$1"; dest="$2"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
      rm -f "$dest"
    else
      echo "Leaving $dest alone: not claudia's symlink (edited or replaced?)." >&2
      return 0
    fi
  fi
  if [ -f "$dest.bak" ]; then
    mv "$dest.bak" "$dest"
    echo "Restored $dest from $dest.bak"
  fi
}

uninstall_one() {
  CLAUDE_DIR="$1"
  echo ""
  echo "== $CLAUDE_DIR =="

  remove_and_restore "$REPO_DIR/output-styles/claudia.md" "$CLAUDE_DIR/output-styles/claudia.md"
  remove_and_restore "$REPO_DIR/skills/fresh-work/SKILL.md" "$CLAUDE_DIR/skills/fresh-work/SKILL.md"
  remove_and_restore "$REPO_DIR/skills/claudia-debt/SKILL.md" "$CLAUDE_DIR/skills/claudia-debt/SKILL.md"
  remove_and_restore "$REPO_DIR/skills/doc-router/SKILL.md" "$CLAUDE_DIR/skills/doc-router/SKILL.md"
  remove_and_restore "$REPO_DIR/agents/claudia.md" "$CLAUDE_DIR/agents/claudia.md"
  remove_and_restore "$REPO_DIR/agents/bulk-reader.md" "$CLAUDE_DIR/agents/bulk-reader.md"
  remove_and_restore "$REPO_DIR/hooks/read-guard.sh" "$CLAUDE_DIR/hooks/read-guard.sh"
  remove_and_restore "$REPO_DIR/hooks/read-guard.py" "$CLAUDE_DIR/hooks/read-guard.py"
  remove_and_restore "$REPO_DIR/hooks/session-boot.sh" "$CLAUDE_DIR/hooks/session-boot.sh"
  remove_and_restore "$REPO_DIR/hooks/session-boot.py" "$CLAUDE_DIR/hooks/session-boot.py"
  rmdir "$CLAUDE_DIR/skills/fresh-work" 2>/dev/null || true
  rmdir "$CLAUDE_DIR/skills/claudia-debt" 2>/dev/null || true
  rmdir "$CLAUDE_DIR/skills/doc-router" 2>/dev/null || true
  rmdir "$CLAUDE_DIR/hooks" 2>/dev/null || true

  # Inverse of install's register_hooks: prune the entries claudia added,
  # never rewrite hooks it didn't.
  SETTINGS="$CLAUDE_DIR/settings.json"
  if [ -f "$SETTINGS" ] && command -v python3 >/dev/null 2>&1; then
    if python3 "$REPO_DIR/lib_settings.py" hooks-off "$SETTINGS"; then
      echo "Stripped claudia hooks from $SETTINGS"
    else
      echo "Left $SETTINGS untouched; remove the claudia hooks by hand." >&2
    fi
  fi

  CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
  if [ -f "$CLAUDE_MD" ]; then
    check_markers "$CLAUDE_MD" "$MARKER_START" "$MARKER_END"
    case "$MARKER_STATUS" in
      paired)
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
        echo "Removed claudia block from $CLAUDE_MD"
        ;;
      absent)
        : # nothing to remove
        ;;
      malformed)
        echo "Malformed or duplicate claudia markers in $CLAUDE_MD; leaving it untouched — remove by hand." >&2
        ;;
    esac
  fi

  echo "Uninstalled claudia files from $CLAUDE_DIR."
}

while IFS= read -r dir; do
  uninstall_one "$dir"
done < "$SELECTED_FILE"

echo ""
echo "If outputStyle is still set to claudia in settings.json, change it via /config."
