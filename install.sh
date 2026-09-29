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
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    if [ -f "$dest.bak" ]; then
      echo "Refusing to touch $dest: it's a real file (not claudia's symlink)" >&2
      echo "and $dest.bak already exists. Move or remove one by hand and re-run." >&2
      return 1
    fi
    mv "$dest" "$dest.bak"
    echo "Backed up existing $dest -> $dest.bak"
  else
    rm -f "$dest"
  fi
  ln -s "$src" "$dest"
  echo "Linked $dest -> $src"
}

settings_edit() {
  settings="$1/settings.json"
  op="$2"
  shift 2
  if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 not found, can't edit $settings." >&2
    return 1
  fi
  python3 "$REPO_DIR/lib_settings.py" "$op" "$settings" "$@"
}

set_output_style() {
  if settings_edit "$1" style; then
    echo "Set outputStyle: claudia in $1/settings.json"
  else
    echo "Run /config in Claude Code and select Output style -> claudia instead." >&2
    return 1
  fi
}

# The hooks are the payload, not the voice — register them unconditionally,
# not behind the outputStyle prompt.
register_hooks() {
  if settings_edit "$1" hooks-on "$1/hooks/read-guard.sh"; then
    echo "Registered PreToolUse read guard in $1/settings.json"
  else
    echo "Read guard NOT registered; fix $1/settings.json and re-run." >&2
  fi
  if settings_edit "$1" hooks-on "$1/hooks/session-boot.sh"; then
    echo "Registered SessionStart pre-flight reminder in $1/settings.json"
  else
    echo "Session-boot hook NOT registered; fix $1/settings.json and re-run." >&2
  fi
}

install_one() {
  CLAUDE_DIR="$1"
  echo ""
  echo "== $CLAUDE_DIR =="

  mkdir -p "$CLAUDE_DIR/output-styles" "$CLAUDE_DIR/skills/fresh-work" \
    "$CLAUDE_DIR/skills/claudia-debt" "$CLAUDE_DIR/skills/doc-router" \
    "$CLAUDE_DIR/agents" "$CLAUDE_DIR/hooks"

  link_and_backup "$REPO_DIR/output-styles/claudia.md" "$CLAUDE_DIR/output-styles/claudia.md"
  link_and_backup "$REPO_DIR/skills/fresh-work/SKILL.md" "$CLAUDE_DIR/skills/fresh-work/SKILL.md"
  link_and_backup "$REPO_DIR/skills/claudia-debt/SKILL.md" "$CLAUDE_DIR/skills/claudia-debt/SKILL.md"
  link_and_backup "$REPO_DIR/skills/doc-router/SKILL.md" "$CLAUDE_DIR/skills/doc-router/SKILL.md"
  link_and_backup "$REPO_DIR/agents/claudia.md" "$CLAUDE_DIR/agents/claudia.md"
  link_and_backup "$REPO_DIR/agents/bulk-reader.md" "$CLAUDE_DIR/agents/bulk-reader.md"
  link_and_backup "$REPO_DIR/hooks/read-guard.sh" "$CLAUDE_DIR/hooks/read-guard.sh"
  link_and_backup "$REPO_DIR/hooks/read-guard.py" "$CLAUDE_DIR/hooks/read-guard.py"
  link_and_backup "$REPO_DIR/hooks/session-boot.sh" "$CLAUDE_DIR/hooks/session-boot.sh"
  link_and_backup "$REPO_DIR/hooks/session-boot.py" "$CLAUDE_DIR/hooks/session-boot.py"

  # CLAUDE.md can't be symlinked whole (it holds the user's own content too),
  # so the fenced block holds a single @import line instead of a pasted copy.
  CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
  touch "$CLAUDE_MD"
  IMPORT_LINE="@$REPO_DIR/CLAUDE.md.snippet"
  check_markers "$CLAUDE_MD" "$MARKER_START" "$MARKER_END"
  case "$MARKER_STATUS" in
    paired)
      awk -v s="$MARKER_START" -v e="$MARKER_END" -v imp="$IMPORT_LINE" '
        index($0, s) { print; print imp; skip = 1; next }
        skip && index($0, e) { print; skip = 0; next }
        skip { next }
        { print }
      ' "$CLAUDE_MD" > "$CLAUDE_MD.tmp" && mv "$CLAUDE_MD.tmp" "$CLAUDE_MD"
      echo "claudia block in $CLAUDE_MD now @imports the repo"
      ;;
    absent)
      printf '\n%s\n%s\n%s\n' "$MARKER_START" "$IMPORT_LINE" "$MARKER_END" >> "$CLAUDE_MD"
      echo "Appended claudia @import block to $CLAUDE_MD"
      ;;
    malformed)
      echo "Malformed or duplicate claudia markers in $CLAUDE_MD; fix by hand and re-run." >&2
      exit 1
      ;;
  esac

  register_hooks "$CLAUDE_DIR"

  echo "Linked output-style, fresh-work + claudia-debt + doc-router skills,"
  echo "the claudia + bulk-reader agents, and the read guard + session-boot"
  echo "hooks straight to the repo."

  do_set=0
  if [ "$FORCE_OUTPUT_STYLE" = "1" ]; then
    do_set=1
  elif [ -t 0 ]; then
    printf "Set Output style -> claudia in %s/settings.json now? [y/N]: " "$CLAUDE_DIR"
    read -r ans
    case "$ans" in y|Y|yes|YES) do_set=1 ;; esac
  fi

  if [ "$do_set" = "1" ]; then
    # Non-fatal: the hooks are already registered; keep going to the next dir.
    set_output_style "$CLAUDE_DIR" || echo "outputStyle NOT set in $CLAUDE_DIR; continuing." >&2
  else
    echo "To activate the voice/ladder, run /config in Claude Code (with"
    echo "CLAUDE_CONFIG_DIR=$CLAUDE_DIR if applicable) and select Output style -> claudia."
  fi
}

while IFS= read -r dir; do
  install_one "$dir"
done < "$SELECTED_FILE"
