"""SessionStart hook body. Invoked by session-boot.sh with the hook event on
stdin. Prints an additionalContext payload or nothing.

Deliberately short and non-duplicative of CLAUDE.md.snippet's ladder text
(already loaded every session via @import) - this is a pre-flight nudge,
not a restatement of the rules.
"""

import json
import sys

REMINDER = (
    "claudia pre-flight, before the first substantive action: (1) does this "
    "need delegation - bulk read -> bulk-reader; mechanical/multi-file -> "
    "haiku; any code-writing -> claudia agent with an explicit model tier "
    "set? (2) does a self-triggering skill apply (fresh-work, claudia-debt, "
    "doc-router) without being asked? Check both before starting, not after."
)


def main():
    try:
        json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": "SessionStart",
                "additionalContext": REMINDER,
            }
        },
        sys.stdout,
    )
    sys.exit(0)


main()
