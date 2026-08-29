#!/bin/sh
# Seeds a sandbox's config dir with a real claudia install by literally
# running install.sh against it, so the "claudia" arm of the eval can
# never drift from what a real install produces.
#
# Usage: seed_claudia.sh <sandbox-home-dir>
set -eu

SANDBOX_HOME="$1"
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

# env -i: no inherited CLAUDE_CONFIG_DIR/HOME from the real session, same
# isolation idiom as tests/install_test.sh's run_install().
env -i HOME="$SANDBOX_HOME" PATH="$PATH" \
  sh "$REPO_DIR/install.sh" --set-output-style < /dev/null > /dev/null
