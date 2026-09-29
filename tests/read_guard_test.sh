#!/bin/sh
# Drives hooks/read-guard.sh with fixture PreToolUse events. No Claude Code in
# the loop: stdin is the event, a non-empty stdout is a deny.
set -eu

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GUARD="$REPO_DIR/hooks/read-guard.sh"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

seq 1 1000 > "$SANDBOX/big.txt"
seq 1 10 > "$SANDBOX/small.txt"
printf 'a\0b\n' > "$SANDBOX/bin.dat"

FAIL=0

# want: DENY | allow
check() {
  want="$1"; name="$2"; event="$3"
  got="allow"
  [ -n "$(printf '%s' "$event" | "$GUARD" 2>/dev/null)" ] && got="DENY"
  if [ "$got" != "$want" ]; then
    echo "FAIL: $name — wanted $want, got $got"
    FAIL=1
  fi
}

read_event() { printf '{"tool_name":"Read","tool_input":%s,"cwd":"%s"}' "$1" "$SANDBOX"; }
bash_event() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"},"cwd":"%s"}' "$1" "$SANDBOX"; }

echo "== read guard: Read =="
check DENY  "oversized read"        "$(read_event '{"file_path":"big.txt"}')"
check DENY  "absolute path"         "$(read_event "{\"file_path\":\"$SANDBOX/big.txt\"}")"
check allow "offset exemption"      "$(read_event '{"file_path":"big.txt","offset":1,"limit":50}')"
check allow "limit exemption"       "$(read_event '{"file_path":"big.txt","limit":50}')"
check allow "under threshold"       "$(read_event '{"file_path":"small.txt"}')"
check allow "missing file"          "$(read_event '{"file_path":"nope.txt"}')"
check allow "binary file"           "$(read_event '{"file_path":"bin.dat"}')"
check allow "no file_path"          "$(read_event '{}')"

echo "== read guard: Bash pagers =="
check DENY  "cat big"               "$(bash_event 'cat big.txt')"
check DENY  "less big"              "$(bash_event 'less big.txt')"
check allow "head big, no count"    "$(bash_event 'head big.txt')"
check allow "tail big, no count"    "$(bash_event 'tail big.txt')"
check allow "tail -f big"           "$(bash_event 'tail -f big.txt')"
check allow "head -50"              "$(bash_event 'head -50 big.txt')"
check allow "tail -n 20"            "$(bash_event 'tail -n 20 big.txt')"
check allow "head --lines=10"       "$(bash_event 'head --lines=10 big.txt')"
check allow "tail --bytes=200"      "$(bash_event 'tail --bytes=200 big.txt')"
check allow "piped, ambiguous"      "$(bash_event 'cat big.txt | head')"
check allow "redirect, ambiguous"   "$(bash_event 'cat big.txt > out')"
check allow "cat under threshold"   "$(bash_event 'cat small.txt')"
check allow "not a pager"           "$(bash_event 'grep -n foo big.txt')"
check allow "unbalanced quote"      "$(bash_event 'cat \"big.txt')"

echo "== read guard: fails open =="
check allow "other tool"            '{"tool_name":"Edit","tool_input":{"file_path":"big.txt"}}'
check allow "unparseable event"     'not json at all'
check allow "empty stdin"           ''
CLAUDIA_READ_GUARD_LINES=0 \
  check allow "kill switch"         "$(read_event '{"file_path":"big.txt"}')"

if [ "$FAIL" = "0" ]; then
  echo "PASS"
else
  echo "FAIL"
  exit 1
fi
