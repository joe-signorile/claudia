#!/bin/sh
# Runs the real-world-repo half of the claudia eval: a single hard,
# genuinely-deferred italy-rs roadmap task, one trial per condition, each
# on its own git worktree/branch in the real italy-rs repo. Unlike
# eval/unit.sh's throwaway fixtures, this is a two-stage session per
# condition — plan mode first, then an auto-approved resume to execute —
# because a task this size is meant to be planned before it's built, the
# same way a human would drive it.
#
# No budget cap (deliberately — this is a single deep case study, not a
# statistical corpus entry averaged over cheap trials).
#
# --batch <name> targets an existing eval/runs/ batch instead of starting
# a new one (used by eval/run.sh to fold multiple tiers into one batch),
# and doubles as resume: a condition whose run_dir is already complete+
# valid (per eval/lib/run_status.py — same check unit.sh's --resume uses)
# is skipped, worktree and all. A condition that's present but incomplete
# (a prior crash) gets its stale worktree/branch torn down and redone.
# The judge call at the end is never cached — always fresh.
#
# Usage:
#   ./eval/integration.sh                        # runs gsplat-resample-01, sonnet/medium
#   EVAL_MODEL=opus EVAL_EFFORT=high ./eval/integration.sh   # the opus/high tier
#   ./eval/integration.sh --task foo-01           # a different eval/tasks/ task
#   ./eval/integration.sh --batch 20260829T152616Z  # target/resume a batch
#   ITALY_REPO=/path/to/italy-rs ./eval/integration.sh
#   EVAL_BASE_BRANCH=claudia-integration-eval ./eval/integration.sh   # default
#
# Per-condition branches fork off EVAL_BASE_BRANCH, not master directly —
# a dedicated, remote-pushed branch so the eval has a stable, known-good
# anchor point independent of whatever master does next.
#
# Each (model, effort) tier gets its own task-id directory
# (<task_id>--<model>-<effort>) so running both the sonnet/medium and
# opus/high tiers writes side by side in the same batch without
# clobbering each other — aggregate.py strips the "--<tier>" suffix to
# find the underlying task file's category/checklist.
#
# Writes into $BATCH_DIR/<task_id>--<tier>/<condition>/1/ — same shape as
# eval/unit.sh (just a longer task-id folder name), so eval/eval.sh can
# aggregate+report either or both.
set -eu

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$REPO_DIR/eval/lib/sandbox.sh"

: "${ITALY_REPO:=$HOME/projects/italy-rs}"
: "${EVAL_BASE_BRANCH:=claudia-integration-eval}"
: "${EVAL_MODEL:=sonnet}"
: "${EVAL_EFFORT:=medium}"
: "${CLAUDE_CODE_SUBAGENT_MODEL:=sonnet}"
: "${EVAL_JUDGE_MODEL:=sonnet}"
: "${EVAL_JUDGE_EFFORT:=high}"
: "${EVAL_CONDITIONS:=vanilla,claudia}"
export CLAUDE_CODE_SUBAGENT_MODEL

TIER="${EVAL_MODEL}-${EVAL_EFFORT}"

TASK_ID="gsplat-resample-01"
BATCH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --task) shift; TASK_ID="$1" ;;
    --batch) shift; BATCH="$1" ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
  shift
done

[ -d "$ITALY_REPO/.git" ] || { echo "not a git repo: $ITALY_REPO (set ITALY_REPO)" >&2; exit 1; }
task_file="$REPO_DIR/eval/tasks/$TASK_ID.md"
[ -f "$task_file" ] || { echo "no such task file: $task_file" >&2; exit 1; }
command -v uuidgen >/dev/null 2>&1 || { echo "uuidgen required (session-id for the plan/execute resume)" >&2; exit 1; }

[ -n "$BATCH" ] || BATCH="$(date -u +%Y%m%dT%H%M%SZ)"
BATCH_DIR="$REPO_DIR/eval/runs/$BATCH"
mkdir -p "$BATCH_DIR"
echo "Batch: $BATCH_DIR"

prompt_file="$(mktemp)"
awk '/^---$/{c++; next} c>=2' "$task_file" > "$prompt_file"
prompt="$(cat "$prompt_file")"
rm -f "$prompt_file"

git -C "$ITALY_REPO" rev-parse --verify "$EVAL_BASE_BRANCH" >/dev/null 2>&1 || {
  echo "no such base branch in $ITALY_REPO: $EVAL_BASE_BRANCH (set EVAL_BASE_BRANCH)" >&2
  exit 1
}
base_ref="$(git -C "$ITALY_REPO" rev-parse "$EVAL_BASE_BRANCH")"
echo "Branch point: $EVAL_BASE_BRANCH @ $base_ref"

run_condition() {
  # run_condition <condition>
  condition="$1"
  branch="eval/${TASK_ID}-${TIER}-${condition}"
  worktree_dir="$ITALY_REPO/.claude/worktrees/eval-${TASK_ID}-${TIER}-${condition}"
  run_dir="$BATCH_DIR/${TASK_ID}--${TIER}/$condition/1"

  if python3 "$REPO_DIR/eval/lib/run_status.py" run "$run_dir" >/dev/null 2>&1; then
    echo "  [$condition] already complete, skipping"
    return 0
  fi

  # A prior incomplete attempt may have left a worktree/branch behind —
  # tear it down so worktree add below starts clean.
  if git -C "$ITALY_REPO" worktree list --porcelain | grep -qx "worktree $worktree_dir"; then
    git -C "$ITALY_REPO" worktree remove --force "$worktree_dir"
  fi
  if git -C "$ITALY_REPO" show-ref --verify --quiet "refs/heads/$branch"; then
    git -C "$ITALY_REPO" branch -D "$branch" >/dev/null
  fi

  mkdir -p "$run_dir"
  git -C "$ITALY_REPO" worktree add -b "$branch" "$worktree_dir" "$EVAL_BASE_BRANCH"

  sandbox="$(make_sandbox)"
  trap 'cleanup_sandbox "$sandbox"' EXIT INT TERM
  set +e

  config_dir="$sandbox/home/.claude"
  sid="$(uuidgen)"

  echo "  [$condition] plan stage (session $sid)"
  if [ "$condition" = "claudia" ]; then
    sh "$REPO_DIR/eval/lib/seed_claudia.sh" "$sandbox/home"
    ( cd "$worktree_dir" && \
      CLAUDE_CONFIG_DIR="$config_dir" HOME="$sandbox/home" \
      claude -p "$prompt" \
        --model "$EVAL_MODEL" --effort "$EVAL_EFFORT" --session-id "$sid" \
        --output-format stream-json --verbose --forward-subagent-text \
        --permission-mode plan \
    ) > "$run_dir/plan.ndjson" 2> "$run_dir/plan.stderr.log"
  else
    # Defense in depth on top of the empty CLAUDE_CONFIG_DIR: load no
    # user/project/local settings at all for the vanilla arm.
    ( cd "$worktree_dir" && \
      CLAUDE_CONFIG_DIR="$config_dir" HOME="$sandbox/home" \
      claude -p "$prompt" \
        --model "$EVAL_MODEL" --effort "$EVAL_EFFORT" --session-id "$sid" \
        --output-format stream-json --verbose --forward-subagent-text \
        --permission-mode plan --setting-sources "" \
    ) > "$run_dir/plan.ndjson" 2> "$run_dir/plan.stderr.log"
  fi

  echo "  [$condition] execute stage (resume $sid, auto-approving plan + all tool calls)"
  if [ "$condition" = "claudia" ]; then
    ( cd "$worktree_dir" && \
      CLAUDE_CONFIG_DIR="$config_dir" HOME="$sandbox/home" \
      claude -p "Proceed with the plan." \
        --model "$EVAL_MODEL" --effort "$EVAL_EFFORT" --resume "$sid" \
        --output-format stream-json --verbose --forward-subagent-text \
        --permission-mode bypassPermissions \
    ) > "$run_dir/execute.ndjson" 2> "$run_dir/execute.stderr.log"
  else
    ( cd "$worktree_dir" && \
      CLAUDE_CONFIG_DIR="$config_dir" HOME="$sandbox/home" \
      claude -p "Proceed with the plan." \
        --model "$EVAL_MODEL" --effort "$EVAL_EFFORT" --resume "$sid" \
        --output-format stream-json --verbose --forward-subagent-text \
        --permission-mode bypassPermissions --setting-sources "" \
    ) > "$run_dir/execute.ndjson" 2> "$run_dir/execute.stderr.log"
  fi
  echo "$?" > "$run_dir/exit_code"

  cat "$run_dir/plan.ndjson" "$run_dir/execute.ndjson" > "$run_dir/transcript.ndjson"
  git -C "$worktree_dir" diff "$base_ref" > "$run_dir/diff.patch"
  python3 "$REPO_DIR/eval/lib/metrics.py" "$task_file" "$worktree_dir" "$base_ref" > "$run_dir/metrics.json"
  python3 "$REPO_DIR/eval/lib/extract_summary.py" "$run_dir/transcript.ndjson" "$run_dir/diff.patch" > "$run_dir/summary.json"
  python3 "$REPO_DIR/eval/lib/check_activation.py" "$run_dir/transcript.ndjson" "$condition" > "$run_dir/activation.json"
  python3 "$REPO_DIR/eval/lib/token_usage.py" "$run_dir/plan.ndjson" "$run_dir/execute.ndjson" > "$run_dir/tokens.json"

  if ! grep -q '"activation_ok": true' "$run_dir/activation.json" 2>/dev/null; then
    echo "  WARNING: activation check failed for $condition — excluded from scoring, see $run_dir/activation.json" >&2
  fi
  if [ "$(cat "$run_dir/exit_code" 2>/dev/null)" != "0" ]; then
    echo "  WARNING: claude exited non-zero for $condition — see $run_dir/execute.stderr.log, excluded from scoring" >&2
  fi

  cleanup_sandbox "$sandbox"
  trap - EXIT INT TERM
  set -e
}

echo "== $TASK_ID ($TIER) =="
branches=""
for condition in $(echo "$EVAL_CONDITIONS" | tr ',' ' '); do
  echo "-- $condition --"
  run_condition "$condition"
  branches="$branches $condition:eval/${TASK_ID}-${TIER}-${condition}"
done

task_dir_name="${TASK_ID}--${TIER}"
vanilla_summary="$BATCH_DIR/$task_dir_name/vanilla/1/summary.json"
claudia_summary="$BATCH_DIR/$task_dir_name/claudia/1/summary.json"
if [ -f "$vanilla_summary" ] && [ -f "$claudia_summary" ]; then
  echo "Judging..."
  judge_dir="$BATCH_DIR/$task_dir_name/judge"
  mkdir -p "$judge_dir"
  set +e
  python3 "$REPO_DIR/eval/judge/judge.py" "$task_file" "$vanilla_summary" "$claudia_summary" "$EVAL_JUDGE_MODEL" "$EVAL_JUDGE_EFFORT" \
    > "$judge_dir/1.json.tmp" 2> "$judge_dir/1.stderr.log"
  status=$?
  set -e
  if [ "$status" -eq 0 ]; then
    mv "$judge_dir/1.json.tmp" "$judge_dir/1.json"
  else
    rm -f "$judge_dir/1.json.tmp"
    echo "  WARNING: judge failed (exit $status) — see $judge_dir/1.stderr.log" >&2
  fi
fi

# Committed, human-readable copies — eval/runs/ is gitignored, this isn't.
case_dir="$REPO_DIR/eval/case-studies/$task_dir_name"
mkdir -p "$case_dir"
for condition in vanilla claudia; do
  src="$BATCH_DIR/$task_dir_name/$condition/1/diff.patch"
  [ -f "$src" ] && cp "$src" "$case_dir/$condition.diff"
done

echo "Done. Batch: $BATCH_DIR"
echo "Diffs copied to $case_dir (fill in $case_dir/README.md by hand)."
echo "Branches created in $ITALY_REPO:$branches"
echo "Aggregate + report: EVAL_TRIALS=1 ./eval/eval.sh $BATCH_DIR"
echo "Cleanup when done inspecting (from $ITALY_REPO):"
for condition in $(echo "$EVAL_CONDITIONS" | tr ',' ' '); do
  echo "  git worktree remove .claude/worktrees/eval-${TASK_ID}-${TIER}-${condition} && git branch -D eval/${TASK_ID}-${TIER}-${condition}"
done
