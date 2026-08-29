#!/bin/sh
# Copies a named fixture tree into a throwaway repo and commits it, so the
# post-run `git diff` is exactly the model's change.
#
# Usage: fixtures.sh <fixture-id> <dest-repo-dir>
set -eu

FIXTURE="$1"
DEST_REPO="$2"
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE_DIR="$REPO_DIR/eval/fixtures/$FIXTURE"

[ -d "$FIXTURE_DIR" ] || { echo "unknown fixture: $FIXTURE" >&2; exit 1; }

cp -R "$FIXTURE_DIR/." "$DEST_REPO/"
git -C "$DEST_REPO" init -q
git -C "$DEST_REPO" -c user.email=eval@localhost -c user.name=eval add -A
git -C "$DEST_REPO" -c user.email=eval@localhost -c user.name=eval \
  commit -q -m fixture
