# Shared Claude config-dir discovery/selection, sourced by install.sh and
# uninstall.sh. Not shipped to ~/.claude/ — repo-local tooling only.

# Append $1 to the candidate list ($CANDIDATES_FILE) if it isn't already there.
add_candidate() {
  dir="$1"
  [ -n "$dir" ] || return 0
  grep -qxF "$dir" "$CANDIDATES_FILE" 2>/dev/null && return 0
  printf '%s\n' "$dir" >> "$CANDIDATES_FILE"
}

# Populate $CANDIDATES_FILE with every Claude config dir we can find:
# the default, $CLAUDE_CONFIG_DIR, sibling $HOME/.claude-* dirs, any
# $HOME/*/.claude*/ one level down that looks like a real config dir
# (has both CLAUDE.md and settings.json), and any CLAUDE_CONFIG_DIR=...
# assignment in a shell rc file (e.g. a second-account alias).
discover_candidates() {
  add_candidate "$HOME/.claude"
  [ -n "${CLAUDE_CONFIG_DIR:-}" ] && add_candidate "$CLAUDE_CONFIG_DIR"

  for d in "$HOME"/.claude-*/; do
    [ -d "$d" ] || continue
    add_candidate "${d%/}"
  done

  for d in "$HOME"/*/.claude*/; do
    [ -d "$d" ] || continue
    d="${d%/}"
    [ -f "$d/CLAUDE.md" ] || continue
    [ -f "$d/settings.json" ] || continue
    add_candidate "$d"
  done

  for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.zprofile" "$HOME/.bash_profile" "$HOME/.profile"; do
    [ -f "$rc" ] || continue
    grep -o 'CLAUDE_CONFIG_DIR=[^ "'"'"']*' "$rc" 2>/dev/null | sed 's/^CLAUDE_CONFIG_DIR=//' | while IFS= read -r raw; do
      case "$raw" in
        \$HOME/*) raw="$HOME/${raw#\$HOME/}" ;;
        \~/*) raw="$HOME/${raw#\~/}" ;;
      esac
      printf '%s\n' "$raw"
    done >> "$CANDIDATES_FILE.rc"
    if [ -f "$CANDIDATES_FILE.rc" ]; then
      while IFS= read -r raw; do add_candidate "$raw"; done < "$CANDIDATES_FILE.rc"
      rm -f "$CANDIDATES_FILE.rc"
    fi
  done
}

# Discover candidates, then write the chosen subset to $SELECTED_FILE.
# $1: action label used in prompts, e.g. "Install into" / "Uninstall from".
select_dirs() {
  action="$1"
  discover_candidates

  CANDIDATE_COUNT="$(wc -l < "$CANDIDATES_FILE" | tr -d ' ')"
  DEFAULT_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

  if [ "$CANDIDATE_COUNT" -le 1 ]; then
    cp "$CANDIDATES_FILE" "$SELECTED_FILE"
  elif [ ! -t 0 ]; then
    # Multiple accounts found but no tty to ask (CI/piped): only touch the
    # default dir. Never guess "all" here.
    printf '%s\n' "$DEFAULT_DIR" > "$SELECTED_FILE"
    echo "Found multiple Claude Code config dirs, but not running interactively."
    echo "${action} the default only: $DEFAULT_DIR"
    echo "(Other dirs found: $(grep -vxF "$DEFAULT_DIR" "$CANDIDATES_FILE" | tr '\n' ' ')). Re-run interactively to pick them."
  else
    echo "Found multiple Claude Code config dirs:"
    i=0
    while IFS= read -r d; do
      i=$((i + 1))
      echo "  $i) $d"
    done < "$CANDIDATES_FILE"
    echo ""
    printf "%s which? (numbers separated by spaces, or 'all') [all]: " "$action"
    read -r choice
    choice="${choice:-all}"
    if [ "$choice" = "all" ]; then
      cp "$CANDIDATES_FILE" "$SELECTED_FILE"
    else
      for n in $choice; do
        sed -n "${n}p" "$CANDIDATES_FILE" >> "$SELECTED_FILE"
      done
    fi
  fi
}
