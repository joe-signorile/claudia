#!/bin/sh
# SessionStart hook. Injects a short claudia pre-flight reminder as
# additionalContext at the start of a session. Registered by install.sh;
# stripped by uninstall.sh.
#
# Fails open everywhere: kill switch set, python3 absent, body crashed,
# unparseable event -> no output, session starts exactly as it would
# without this hook.
set -u

[ "${CLAUDIA_SESSION_BOOT:-1}" = "0" ] && exit 0
command -v python3 >/dev/null 2>&1 || exit 0

# stdin stays the hook event; the body is a file, not a heredoc.
python3 "$(dirname "$0")/session-boot.py" 2>/dev/null
exit 0
