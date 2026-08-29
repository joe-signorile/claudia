#!/bin/sh
# Aggregates + reports a batch produced by eval/unit.sh and/or
# eval/integration.sh — the tail end both scripts used to run inline,
# lifted out so a batch dir can be reported on regardless of which
# script(s) wrote into it (they share the same
# $BATCH_DIR/<task_id>/<condition>/<trial>/ artifact shape).
#
# Usage:
#   ./eval/eval.sh <batch_dir>
#   ./eval/eval.sh eval/runs/20260829T152616Z
#
# Env knobs (must match what produced the batch — same defaults as
# eval/unit.sh/eval/integration.sh):
#   EVAL_TRIALS (default 5), EVAL_MODEL (default sonnet),
#   EVAL_JUDGE_MODEL (default sonnet)
set -eu

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

: "${EVAL_TRIALS:=5}"
: "${EVAL_MODEL:=sonnet}"
: "${EVAL_JUDGE_MODEL:=sonnet}"

[ $# -eq 1 ] || { echo "usage: $0 <batch_dir>" >&2; exit 1; }
BATCH_DIR="$1"
[ -d "$BATCH_DIR" ] || { echo "no such batch dir: $BATCH_DIR" >&2; exit 1; }

python3 "$REPO_DIR/eval/aggregate.py" "$BATCH_DIR" "$EVAL_MODEL" "$EVAL_JUDGE_MODEL" "$EVAL_TRIALS" \
  > "$REPO_DIR/eval/results/latest.json"
python3 "$REPO_DIR/eval/report.py" "$REPO_DIR/eval/results/latest.json" \
  > "$REPO_DIR/eval/results/latest.md"
echo "Results written to eval/results/latest.json and eval/results/latest.md"
echo "To propagate a good result to README.md: python3 eval/propagate_readme.py"
