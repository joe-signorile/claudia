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
# statistical corpus entry averaged over cheap trials) and no --resume:
# a failed run means removing the worktree/branch this script printed at
# the end and re-running.
#
# Usage:
#   ./eval/integration.sh                        # runs gsplat-resample-01
#   ./eval/integration.sh --task foo-01           # a different eval/tasks/ task
#   ITALY_REPO=/path/to/italy-rs ./eval/integration.sh
#
# Writes into the same $BATCH_DIR/<task_id>/<condition>/1/ shape as
# eval/unit.sh, so eval/eval.sh can aggregate+report either or both.
set -eu

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$REPO_DIR/eval/lib/sandbox.sh"

: "${ITALY_REPO:=$HOME/projects/italy-rs}"
: "${EVAL_MODEL:=sonnet}"
: "${CLAUDE_CODE_SUBAGENT_MODEL:=sonnet}"
: "${EVAL_JUDGE_MODEL:=sonnet}"
: "${EVAL_CONDITIONS:=vanilla,claudia}"
export CLAUDE_CODE_SUBAGENT_MODEL

TASK_ID="gsplat-resample-01"
while [ $# -gt 0 ]; do
  case "$1" in
    --task) shift; TASK_ID="$1" ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
  shift
done

[ -d "$ITALY_REPO/.git" ] || { echo "not a git repo: $ITALY_REPO (set ITALY_REPO)" >&2; exit 1; }
task_file="$REPO_DIR/eval/tasks/$TASK_ID.md"
[ -f "$task_file" ] || { echo "no such task file: $task_file" >&2; exit 1; }
command -v uuidgen >/dev/null 2>&1 || { echo "uuidgen required (session-id for the plan/execute resume)" >&2; exit 1; }

BATCH="$(date -u +%Y%m%dT%H%M%SZ)"
BATCH_DIR="$REPO_DIR/eval/runs/$BATCH"
mkdir -p "$BATCH_DIR"
echo "Batch: $BATCH_DIR"

prompt_file="$(mktemp)"
awk '/^---$/{c++; next} c>=2' "$task_file" > "$prompt_file"
prompt="$(cat "$prompt_file")"
rm -f "$prompt_file"

base_ref="$(git -C "$ITALY_REPO" rev-parse master)"
echo "Branch point: master @ $base_ref"

run_condition() {
  # run_condition <condition>
  condition="$1"
  branch="eval/${TASK_ID}-${condition}"
  worktree_dir="$ITALY_REPO/.claude/worktrees/eval-${TASK_ID}-${condition}"
  run_dir="$BATCH_DIR/$TASK_ID/$condition/1"
  mkdir -p "$run_dir"

  git -C "$ITALY_REPO" worktree add -b "$branch" "$worktree_dir" master

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
        --model "$EVAL_MODEL" --session-id "$sid" \
        --output-format stream-json --verbose --forward-subagent-text \
        --permission-mode plan \
    ) > "$run_dir/plan.ndjson" 2> "$run_dir/plan.stderr.log"
  else
    # Defense in depth on top of the empty CLAUDE_CONFIG_DIR: load no
    # user/project/local settings at all for the vanilla arm.
    ( cd "$worktree_dir" && \
      CLAUDE_CONFIG_DIR="$config_dir" HOME="$sandbox/home" \
      claude -p "$prompt" \
        --model "$EVAL_MODEL" --session-id "$sid" \
        --output-format stream-json --verbose --forward-subagent-text \
        --permission-mode plan --setting-sources "" \
    ) > "$run_dir/plan.ndjson" 2> "$run_dir/plan.stderr.log"
  fi

  echo "  [$condition] execute stage (resume $sid, auto-approving plan + all tool calls)"
  if [ "$condition" = "claudia" ]; then
    ( cd "$worktree_dir" && \
      CLAUDE_CONFIG_DIR="$config_dir" HOME="$sandbox/home" \
      claude -p "Proceed with the plan." \
        --model "$EVAL_MODEL" --resume "$sid" \
        --output-format stream-json --verbose --forward-subagent-text \
        --permission-mode bypassPermissions \
    ) > "$run_dir/execute.ndjson" 2> "$run_dir/execute.stderr.log"
  else
    ( cd "$worktree_dir" && \
      CLAUDE_CONFIG_DIR="$config_dir" HOME="$sandbox/home" \
      claude -p "Proceed with the plan." \
        --model "$EVAL_MODEL" --resume "$sid" \
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

echo "== $TASK_ID =="
branches=""
for condition in $(echo "$EVAL_CONDITIONS" | tr ',' ' '); do
  echo "-- $condition --"
  run_condition "$condition"
  branches="$branches $condition:eval/${TASK_ID}-${condition}"
done

vanilla_summary="$BATCH_DIR/$TASK_ID/vanilla/1/summary.json"
claudia_summary="$BATCH_DIR/$TASK_ID/claudia/1/summary.json"
if [ -f "$vanilla_summary" ] && [ -f "$claudia_summary" ]; then
  echo "Judging..."
  judge_dir="$BATCH_DIR/$TASK_ID/judge"
  mkdir -p "$judge_dir"
  set +e
  python3 "$REPO_DIR/eval/judge/judge.py" "$task_file" "$vanilla_summary" "$claudia_summary" "$EVAL_JUDGE_MODEL" \
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
case_dir="$REPO_DIR/eval/case-studies/$TASK_ID"
mkdir -p "$case_dir"
for condition in vanilla claudia; do
  src="$BATCH_DIR/$TASK_ID/$condition/1/diff.patch"
  [ -f "$src" ] && cp "$src" "$case_dir/$condition.diff"
done

echo "Done. Batch: $BATCH_DIR"
echo "Diffs copied to $case_dir (fill in $case_dir/README.md by hand)."
echo "Branches created in $ITALY_REPO:$branches"
echo "Aggregate + report: EVAL_TRIALS=1 ./eval/eval.sh $BATCH_DIR"
echo "Cleanup when done inspecting (from $ITALY_REPO):"
for condition in $(echo "$EVAL_CONDITIONS" | tr ',' ' '); do
  echo "  git worktree remove .claude/worktrees/eval-${TASK_ID}-${condition} && git branch -D eval/${TASK_ID}-${condition}"
done
