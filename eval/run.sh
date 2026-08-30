#!/bin/sh
# Master orchestrator: the full claudia eval pipeline in one batch —
# sonnet/medium integration, opus/high integration, the unit.sh fixture
# corpus, then aggregate + report + a propagate_readme.py attempt.
#
# Generation runs (both integration tiers, and unit.sh's fixture matrix)
# skip whatever's already complete+valid in the target batch — safe to
# re-invoke after a crash or rate limit, same --resume semantics as
# unit.sh/integration.sh individually. Judging is never skipped: every
# invocation here forces a fresh judge verdict (EVAL_FORCE_JUDGE=1 for
# unit.sh; integration.sh's judge call is unconditional already), always
# at opus/high regardless of what generated the response being judged.
#
# Usage:
#   ./eval/run.sh                    # new batch, full pipeline
#   ./eval/run.sh --resume <batch>   # continue an interrupted run.sh
#
# Env knobs beyond what unit.sh/integration.sh already take:
#   EVAL_JUDGE_MODEL/EVAL_JUDGE_EFFORT are pinned to opus/high here and
#   exported to both sub-scripts — override by setting them before
#   invoking if you want a different judge for one run of this pipeline.
set -eu

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

RESUME=0
BATCH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --resume) shift; RESUME=1; BATCH="$1" ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
  shift
done

if [ "$RESUME" = "1" ]; then
  BATCH_DIR="$REPO_DIR/eval/runs/$BATCH"
  [ -d "$BATCH_DIR" ] || { echo "no such batch to resume: $BATCH_DIR" >&2; exit 1; }
  echo "Resuming batch: $BATCH_DIR"
else
  BATCH="$(date -u +%Y%m%dT%H%M%SZ)"
  BATCH_DIR="$REPO_DIR/eval/runs/$BATCH"
  mkdir -p "$BATCH_DIR"
  echo "Batch: $BATCH_DIR"
fi

: "${EVAL_JUDGE_MODEL:=opus}"
: "${EVAL_JUDGE_EFFORT:=high}"
export EVAL_JUDGE_MODEL EVAL_JUDGE_EFFORT
export EVAL_FORCE_JUDGE=1

echo "== integration: sonnet/medium =="
EVAL_MODEL=sonnet EVAL_EFFORT=medium sh "$REPO_DIR/eval/integration.sh" --batch "$BATCH"

echo "== integration: opus/high =="
EVAL_MODEL=opus EVAL_EFFORT=high sh "$REPO_DIR/eval/integration.sh" --batch "$BATCH"

echo "== unit: fixture corpus =="
sh "$REPO_DIR/eval/unit.sh" --resume "$BATCH"

echo "== aggregate + report =="
sh "$REPO_DIR/eval/eval.sh" "$BATCH_DIR"

echo "== propagate (refuses loudly if margin/regression not cleared) =="
python3 "$REPO_DIR/eval/propagate_readme.py" || echo "propagate_readme.py declined — see output above, latest.md is still up to date"

echo "Done. Batch: $BATCH_DIR"
