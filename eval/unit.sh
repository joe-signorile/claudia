#!/bin/sh
# Runs the synthetic-fixture half of the claudia eval: stock Claude Code
# ("vanilla") vs a real install.sh-seeded claudia install, across the
# small toy-repo task corpus in eval/tasks/, scored by
# eval/judge/judge.py + eval/lib/metrics.py. For the real-repo case study
# (italy-rs), see eval/integration.sh. Neither script aggregates/reports —
# run eval/eval.sh over the resulting batch dir for that.
#
# Usage:
#   ./eval/unit.sh                       # full matrix, new batch
#   ./eval/unit.sh --smoke               # 1 task x 1 trial, validates plumbing
#   ./eval/unit.sh --task foo,bar        # only these task ids
#   ./eval/unit.sh --resume 20260829T152616Z   # re-run an existing batch,
#                                        # skipping any (task, condition,
#                                        # trial) or judge verdict that's
#                                        # already complete and valid —
#                                        # only fills the gap left by a
#                                        # crash, rate limit, or budget cap.
#
# A single run/judge failure never aborts the whole matrix: it's logged
# and skipped, so the rest of the corpus still gets attempted. Re-run with
# --resume <batch> to fill in whatever didn't finish.
#
# Env knobs (see eval/README.md for the full list and cost estimate):
#   EVAL_TRIALS, EVAL_CONDITIONS, EVAL_MODEL, CLAUDE_CODE_SUBAGENT_MODEL,
#   EVAL_JUDGE_MODEL, EVAL_JUDGE_EFFORT, EVAL_PER_RUN_BUDGET,
#   EVAL_FORCE_JUDGE=1 re-judges every trial even under --resume (a cached
#   generation run is still skipped; only the judge verdict is redone)
set -eu

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$REPO_DIR/eval/lib/sandbox.sh"

: "${EVAL_TRIALS:=5}"
: "${EVAL_CONDITIONS:=vanilla,claudia}"
: "${EVAL_MODEL:=sonnet}"
: "${CLAUDE_CODE_SUBAGENT_MODEL:=sonnet}"
: "${EVAL_JUDGE_MODEL:=sonnet}"
: "${EVAL_JUDGE_EFFORT:=}"
: "${EVAL_FORCE_JUDGE:=0}"
: "${EVAL_PER_RUN_BUDGET:=0.50}"
export CLAUDE_CODE_SUBAGENT_MODEL

SMOKE=0
TASK_FILTER=""
RESUME=0
RESUME_BATCH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --smoke) SMOKE=1 ;;
    --task) shift; TASK_FILTER="$1" ;;
    --resume) shift; RESUME=1; RESUME_BATCH="$1" ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
  shift
done

if [ "$SMOKE" = "1" ]; then
  EVAL_TRIALS=1
  [ -n "$TASK_FILTER" ] || TASK_FILTER="minimalism-reuse-01"
fi

if [ "$RESUME" = "1" ]; then
  BATCH="$RESUME_BATCH"
  BATCH_DIR="$REPO_DIR/eval/runs/$BATCH"
  [ -d "$BATCH_DIR" ] || { echo "no such batch to resume: $BATCH_DIR" >&2; exit 1; }
  echo "Resuming batch: $BATCH_DIR"
else
  BATCH="$(date -u +%Y%m%dT%H%M%SZ)"
  BATCH_DIR="$REPO_DIR/eval/runs/$BATCH"
  mkdir -p "$BATCH_DIR"
  echo "Batch: $BATCH_DIR"
fi

if [ -n "$TASK_FILTER" ]; then
  TASK_FILES=""
  for id in $(echo "$TASK_FILTER" | tr ',' ' '); do
    TASK_FILES="$TASK_FILES $REPO_DIR/eval/tasks/$id.md"
  done
else
  TASK_FILES="$REPO_DIR/eval/tasks/"*.md
fi

run_is_cached() {
  # run_is_cached <run_dir> — 0 (true) only under --resume, and only if
  # eval/lib/run_status.py confirms it's a complete, valid prior result.
  [ "$RESUME" = "1" ] || return 1
  python3 "$REPO_DIR/eval/lib/run_status.py" run "$1" >/dev/null 2>&1
}

judge_is_cached() {
  [ "${EVAL_FORCE_JUDGE:-0}" != "1" ] || return 1
  [ "$RESUME" = "1" ] || return 1
  python3 "$REPO_DIR/eval/lib/run_status.py" judge "$1" >/dev/null 2>&1
}

run_one() {
  # run_one <task_file> <task_id> <condition> <trial> <fixture> <prompt_file>
  # Never aborts the script: runs entirely under `set +e` so a crash in
  # any step here is a logged, skippable failure, not a dead batch.
  task_file="$1"; task_id="$2"; condition="$3"; trial="$4"; fixture="$5"; prompt_file="$6"
  run_dir="$BATCH_DIR/$task_id/$condition/$trial"
  mkdir -p "$run_dir"

  sandbox="$(make_sandbox)"
  trap 'cleanup_sandbox "$sandbox"' EXIT INT TERM
  set +e

  sh "$REPO_DIR/eval/lib/fixtures.sh" "$fixture" "$sandbox/repo"

  config_dir="$sandbox/home/.claude"
  prompt="$(cat "$prompt_file")"

  if [ "$condition" = "claudia" ]; then
    sh "$REPO_DIR/eval/lib/seed_claudia.sh" "$sandbox/home"
    ( cd "$sandbox/repo" && \
      CLAUDE_CONFIG_DIR="$config_dir" HOME="$sandbox/home" \
      claude -p "$prompt" \
        --model "$EVAL_MODEL" \
        --output-format stream-json --verbose --forward-subagent-text \
        --permission-mode bypassPermissions \
        --max-budget-usd "$EVAL_PER_RUN_BUDGET" \
    ) > "$run_dir/transcript.ndjson" 2> "$run_dir/stderr.log"
  else
    # Defense in depth on top of the empty CLAUDE_CONFIG_DIR: load no
    # user/project/local settings at all for the vanilla arm.
    ( cd "$sandbox/repo" && \
      CLAUDE_CONFIG_DIR="$config_dir" HOME="$sandbox/home" \
      claude -p "$prompt" \
        --model "$EVAL_MODEL" \
        --output-format stream-json --verbose --forward-subagent-text \
        --permission-mode bypassPermissions \
        --max-budget-usd "$EVAL_PER_RUN_BUDGET" \
        --setting-sources "" \
    ) > "$run_dir/transcript.ndjson" 2> "$run_dir/stderr.log"
  fi
  echo "$?" > "$run_dir/exit_code"

  git -C "$sandbox/repo" diff HEAD > "$run_dir/diff.patch"
  python3 "$REPO_DIR/eval/lib/metrics.py" "$task_file" "$sandbox/repo" > "$run_dir/metrics.json"
  python3 "$REPO_DIR/eval/lib/extract_summary.py" "$run_dir/transcript.ndjson" "$run_dir/diff.patch" > "$run_dir/summary.json"
  python3 "$REPO_DIR/eval/lib/check_activation.py" "$run_dir/transcript.ndjson" "$condition" > "$run_dir/activation.json"
  python3 "$REPO_DIR/eval/lib/token_usage.py" "$run_dir/transcript.ndjson" > "$run_dir/tokens.json"
  if ! grep -q '"activation_ok": true' "$run_dir/activation.json" 2>/dev/null; then
    echo "  WARNING: activation check failed for $condition trial $trial — excluded from scoring, see $run_dir/activation.json" >&2
  fi
  if [ "$(cat "$run_dir/exit_code" 2>/dev/null)" != "0" ]; then
    echo "  WARNING: claude exited non-zero for $condition trial $trial (rate limit/budget/error?) — see $run_dir/stderr.log, excluded from scoring, retry with ./eval/unit.sh --resume $BATCH" >&2
  fi

  cleanup_sandbox "$sandbox"
  trap - EXIT INT TERM
  set -e
}

run_judge() {
  # run_judge <task_file> <task_id> <trial> <vanilla_summary> <claudia_summary>
  # Writes to a .tmp file first and only moves it into place on success,
  # so a crash never leaves a truncated/zero-byte verdict file behind that
  # aggregate.py or a later --resume would have to guess about.
  task_file="$1"; task_id="$2"; trial="$3"; vanilla_summary="$4"; claudia_summary="$5"
  judge_dir="$BATCH_DIR/$task_id/judge"
  mkdir -p "$judge_dir"
  judge_file="$judge_dir/$trial.json"

  if judge_is_cached "$judge_file"; then
    echo "  judge trial $trial (cached, skipping)"
    return 0
  fi

  set +e
  python3 "$REPO_DIR/eval/judge/judge.py" "$task_file" "$vanilla_summary" "$claudia_summary" "$EVAL_JUDGE_MODEL" "$EVAL_JUDGE_EFFORT" \
    > "$judge_file.tmp" 2> "$judge_dir/$trial.stderr.log"
  status=$?
  set -e

  if [ "$status" -eq 0 ]; then
    mv "$judge_file.tmp" "$judge_file"
  else
    rm -f "$judge_file.tmp"
    echo "  WARNING: judge failed for $task_id trial $trial (exit $status) — see $judge_dir/$trial.stderr.log, retry with ./eval/unit.sh --resume $BATCH" >&2
  fi
}

for task_file in $TASK_FILES; do
  [ -f "$task_file" ] || { echo "no such task file: $task_file" >&2; exit 1; }
  task_id="$(basename "$task_file" .md)"
  fixture="$(awk '/^---$/{c++; next} c==1 && /^fixture:/{print $2; exit}' "$task_file")"

  # Integration-only tasks (e.g. gsplat-resample-01, whose "fixture" is the
  # real italy-rs repo, not something under eval/fixtures/) don't belong to
  # unit.sh's throwaway-repo model — running one anyway leaves the sandbox
  # repo empty/non-git (fixtures.sh correctly refuses) and produces a
  # meaningless score, not a missing one. Skip, don't fake a fixture.
  if [ ! -d "$REPO_DIR/eval/fixtures/$fixture" ]; then
    echo "== $task_id: skipping, no eval/fixtures/$fixture (integration-only task — use eval/integration.sh) =="
    continue
  fi

  # Per-task trial count: a task may declare `trials: N` in frontmatter to
  # opt out of the default. Saturated regression-guard tasks — both arms
  # scoring 100% on every trial — declare 1, because repeating a run whose
  # outcome never varies buys no signal, only spend. EVAL_TRIALS stays a
  # global ceiling, so --smoke and cheap partial runs still cap everything.
  task_trials="$(awk '/^---$/{c++; next} c==1 && /^trials:/{print $2; exit}' "$task_file")"
  [ -n "$task_trials" ] || task_trials="$EVAL_TRIALS"
  [ "$task_trials" -le "$EVAL_TRIALS" ] || task_trials="$EVAL_TRIALS"

  prompt_file="$(mktemp)"
  awk '/^---$/{c++; next} c>=2' "$task_file" > "$prompt_file"

  echo "== $task_id (fixture: $fixture, trials: $task_trials) =="

  trial=1
  while [ "$trial" -le "$task_trials" ]; do
    for condition in $(echo "$EVAL_CONDITIONS" | tr ',' ' '); do
      run_dir="$BATCH_DIR/$task_id/$condition/$trial"
      if run_is_cached "$run_dir"; then
        echo "  trial $trial / $condition (cached, skipping)"
      else
        echo "  trial $trial / $condition"
        run_one "$task_file" "$task_id" "$condition" "$trial" "$fixture" "$prompt_file"
      fi
    done

    vanilla_summary="$BATCH_DIR/$task_id/vanilla/$trial/summary.json"
    claudia_summary="$BATCH_DIR/$task_id/claudia/$trial/summary.json"
    if [ -f "$vanilla_summary" ] && [ -f "$claudia_summary" ]; then
      run_judge "$task_file" "$task_id" "$trial" "$vanilla_summary" "$claudia_summary"
    fi

    trial=$((trial + 1))
  done

  rm -f "$prompt_file"
done

echo "Done. Batch: $BATCH_DIR"
echo "Aggregate + report: EVAL_TRIALS=$EVAL_TRIALS ./eval/eval.sh $BATCH_DIR"
echo "If anything above logged a WARNING, re-run: ./eval/unit.sh --resume $BATCH"
