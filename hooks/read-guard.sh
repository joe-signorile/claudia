#!/bin/sh
# PreToolUse guard. Denies whole-file reads over a line threshold and points the
# caller at the bulk-reader agent instead. Registered for Read and Bash by
# install.sh; stripped by uninstall.sh.
#
# Fails open everywhere: kill switch set, python3 absent, body crashed,
# unparseable event, unreadable or binary path, ambiguous shell. A guard that
# can hard-block on its own bug costs more than the tokens it saves.
set -u

LIMIT="${CLAUDIA_READ_GUARD_LINES:-350}"
[ "$LIMIT" = "0" ] && exit 0
command -v python3 >/dev/null 2>&1 || exit 0

# stdin stays the hook event; the body is a file, not a heredoc.
python3 "$(dirname "$0")/read-guard.py" "$LIMIT" 2>/dev/null
exit 0
