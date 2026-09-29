#!/bin/sh
# Drives hooks/session-boot.sh with fixture SessionStart events. No Claude
# Code in the loop: stdin is the event, a non-empty stdout with
# additionalContext means the reminder fired.
set -eu

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$REPO_DIR/hooks/session-boot.sh"

FAIL=0

# want: FIRE | quiet
check() {
  want="$1"; name="$2"; event="$3"
  out="$(printf '%s' "$event" | "$HOOK" 2>/dev/null)"
  got="quiet"
  [ -n "$out" ] && got="FIRE"
  if [ "$got" != "$want" ]; then
    echo "FAIL: $name — wanted $want, got $got"
    FAIL=1
  fi
  if [ "$got" = "FIRE" ]; then
    printf '%s' "$out" | grep -q 'additionalContext' \
      || { echo "FAIL: $name — output missing additionalContext"; FAIL=1; }
  fi
}

echo "== session boot: fires on a real event =="
check FIRE  "startup event" '{"hook_event_name":"SessionStart","source":"startup"}'
check FIRE  "no source field" '{"hook_event_name":"SessionStart"}'

echo "== session boot: fails open =="
check quiet "unparseable event" 'not json at all'
check quiet "empty stdin"       ''
CLAUDIA_SESSION_BOOT=0 \
  check quiet "kill switch"     '{"hook_event_name":"SessionStart","source":"startup"}'

if [ "$FAIL" = "0" ]; then
  echo "PASS"
else
  echo "FAIL"
  exit 1
fi
