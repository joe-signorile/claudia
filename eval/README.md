# claudia eval

Reproducible comparison of stock Claude Code ("vanilla") against a real
`install.sh`-seeded claudia install ("claudia"), across a fixed task
corpus, scored by a blinded LLM judge plus deterministic diff checks. This
is what backs any "Results" numbers in the top-level README — run it
yourself before trusting them.

**The task corpus below is deliberately small and synthetic** — 1-4 file
toy repos, minutes-long tasks. That's enough to catch a ladder rung being
skipped in isolation, but it says nothing about whether the same
discipline holds up under real project weight: a large codebase, existing
conventions to respect, a task too big to hold in one glance. See
[Case studies](#case-studies) for the first attempt at that harder
question — read it as a single data point, not proof, for the same reason
any n=1 result is.

## Methodology

- **Vanilla** = stock Claude Code with an empty config dir — no
  `CLAUDE.md`, no skills, no agents. **Claudia** = the same, but seeded by
  literally running the repo's own `install.sh` into that config dir
  (`eval/lib/seed_claudia.sh`), so this eval can never drift from what a
  real install actually produces. Both arms run via `CLAUDE_CONFIG_DIR`
  pointed at a throwaway tmpdir — the operator's real `~/.claude` is never
  touched. Auth/session state is best-effort copied in from whatever
  config dir `claude` is already logged in under (see
  `eval/lib/sandbox.sh`) so runs can authenticate; behavior-affecting files
  (`CLAUDE.md`, `skills/`, `agents/`, `output-styles/`) are stripped from
  that copy before either arm starts.
- Both arms are pinned to the same top-level model (`EVAL_MODEL`, default
  `sonnet`) and the same default subagent model
  (`CLAUDE_CODE_SUBAGENT_MODEL`), so the only variable under test is
  presence/absence of claudia — not model choice.
- 12 tasks in `eval/tasks/`, each a small fixture repo (`eval/fixtures/`)
  plus a prompt and a per-task checklist of concrete, mechanically-checkable
  yes/no statements — not vague quality scores. Categories: the minimalism
  ladder (reuse/stdlib over reinvention), the safety floor (does
  simplification strip validation/a11y/secrets), root-cause vs. symptom bug
  fixing, the debt-marker convention, response voice/terseness, and the
  delegation ladder (trivial/ambiguous/escalation/none-needed shaped
  tasks). Criteria are drawn directly from `CLAUDE.md.snippet`'s ladder
  text.
- 5 trials per task per condition by default, to average out model
  nondeterminism.
- Scoring is **blinded LLM-judge checklists + deterministic metrics**.
  `eval/judge/judge.py` anonymizes each pair of same-trial runs into
  "Response A"/"Response B" (label assignment and diff display order both
  randomized), asks a fresh `claude -p` call — no shared context with the
  runs being judged — to answer each checklist item true/false per
  response, then re-maps the labels back. Deterministic checks (new
  dependency added, a required string present/absent) are computed
  directly off the diff by `eval/lib/metrics.py`, no LLM involved. A
  trial's score is the fraction of all checks (judged + deterministic)
  that came back true; task scores average over trials; the aggregate
  averages over tasks unweighted, so no category with more tasks in the
  corpus can dominate the headline number. Per-category breakdown is
  always reported alongside the aggregate.

### Quality is paired with token/cost usage, not measured alone

A checklist pass-rate on its own can't tell you whether claudia got there
cheaper or more expensively than vanilla — a tie on quality bought with
50% more output tokens is a materially different result than a tie at a
fraction of the cost, and claudia's whole premise is doing more with less.
`eval/lib/token_usage.py` pulls input/output/cache-read/cache-write tokens
and cost straight from the stream-json transcript's final `result` event
for every run (this also includes the `modelUsage` breakdown across any
delegated subagents, e.g. haiku vs. sonnet — so a claudia run that
correctly delegates cheap work shows up as lower-tier spend here, not just
as a checklist tick). `eval/aggregate.py` rolls this up per task (paired
directly with that task's quality score in the report table) and into an
aggregate mean-per-task figure, plus a model-tier usage total across the
whole batch per condition. None of this is judged or scored against a
target — it's reported plainly so a quality tie or win can be read
alongside what it cost.

### Activation check

Every single run is verified, not assumed. Claude Code's `stream-json`
output includes a `system`/`init` event reporting `output_style`, `agents`,
and `skills` as actually resolved from `CLAUDE_CONFIG_DIR` at process
start — a structural fact, not an inference from the model's behavior.
`eval/lib/check_activation.py` checks that event after every run: the
claudia arm must show `output_style: "claudia"` plus the `claudia` agent
and all three claudia skills present; the vanilla arm must show none of
that. A run that fails this check is excluded from scoring by
`eval/aggregate.py` (never silently averaged in), and its failure is
counted in `activation_failures`/`activation_total` in `latest.json` and
called out as a loud warning at the top of `latest.md` — a high failure
count means the harness itself is misconfigured, not that claudia has no
effect. Verified manually against a real headless run before this was
wired in: asking a claudia-seeded sandbox to recite its own instructions
back correctly returned the exact minimalism-ladder rungs, the exact
delegation tier order, and `claudia` as the active output style.

### Self-bias

The judge is Claude — the same model family as the systems under test.
This is a real, unmitigated self-evaluation bias risk: a model grading
outputs shaped by its own house style may be predisposed to favor either
approach in ways a human or a different model family wouldn't. This
framework has **no independent or human-judge cross-check**. Read every
number this eval produces as directional evidence, not a definitive proof
of superiority. If you want to validate a specific result, the cheapest
check is to read a handful of the raw diffs/transcripts under
`eval/runs/<batch>/` yourself.

## Running it

`eval/unit.sh` runs the synthetic-fixture corpus; `eval/eval.sh` aggregates
and renders whatever batch you point it at (`unit.sh` prints the exact
command at the end of its run). See "Case studies" below for the separate
real-repo runner.

```sh
./eval/unit.sh --smoke        # 1 task x 1 trial, ~4 claude invocations — validates plumbing
./eval/unit.sh                # full matrix
./eval/unit.sh --task minimalism-reuse-01,root-cause-01   # a subset
./eval/eval.sh eval/runs/<batch>   # aggregate + render latest.md/json
```

Requires: `claude` (Claude Code CLI) installed and already authenticated
under your normal config dir, `git`, `python3` (stdlib only, no
`pip install` needed).

Env knobs (all optional):

| Var | Default | Purpose |
|---|---|---|
| `EVAL_TRIALS` | `5` | trials per task per condition |
| `EVAL_CONDITIONS` | `vanilla,claudia` | restrict to one condition for debugging |
| `EVAL_MODEL` | `sonnet` | top-level model, pinned identically on both arms |
| `CLAUDE_CODE_SUBAGENT_MODEL` | `sonnet` | default subagent model, pinned identically on both arms |
| `EVAL_JUDGE_MODEL` | `sonnet` | judge model |
| `EVAL_PER_RUN_BUDGET` | `0.50` | passed to `--max-budget-usd` per main run |

## Cost

Full matrix: 12 tasks x 2 conditions x 5 trials = 120 main `claude -p`
runs (some spawning 0-2 subagent calls on delegation tasks), plus 60
independent judge calls (one per task per trial, each judging both
conditions at once) — roughly **200-260 total `claude` invocations**.
Rough upper-bound spend: `(tasks x conditions x trials) x
EVAL_PER_RUN_BUDGET` for main runs, plus judge calls (no tool use, single
completion each, typically much cheaper). Use `--smoke` first, and `--task`
to size a partial run before committing to the full matrix.

## Case studies

`eval/integration.sh` is a separate runner for a single hard, genuinely
unimplemented roadmap item against a real external repo — currently
[italy-rs](https://github.com/joe-signorile/italy-rs), a 7.6k-LOC
C++/CUDA/OptiX pathtracer that already imports claudia's doctrine via its
own `CLAUDE.md`. Differences from `unit.sh`:

- **One trial per condition**, no averaging — this is a case study, not a
  statistical sample. It still folds into the same `by_task`/`by_category`
  rollup in `latest.json`/`latest.md` (see `eval/report.py`'s note that
  trial counts vary by category), it just carries a different confidence
  level than a 5-trial fixture task.
- **Real branches, not throwaway repos.** Each condition gets its own
  `git worktree`/branch off `master` in the target repo (matching that
  repo's own worktree-per-agent convention), left in place afterward for
  inspection — `integration.sh` prints the exact `git worktree remove`/
  `git branch -D` cleanup commands, it doesn't delete real repo state
  itself.
- **Plan mode, then an auto-approved resume.** A task this size is meant
  to be planned before it's built. Stage one runs with
  `--permission-mode plan` (model proposes a plan, doesn't execute);
  stage two resumes the same session (`--resume`, matched by an explicit
  `--session-id` set on stage one) with `--permission-mode
  bypassPermissions`, auto-approving the plan and every tool call after
  it. Both stages' transcripts are concatenated before the usual
  `extract_summary.py`/`check_activation.py` post-processing, and
  `token_usage.py` sums cost/tokens across both stages — a two-call
  session's real cost is both calls.
- **No budget cap.** Deliberately — capping a single deep case study the
  same way as a cheap fixture trial would just make it fail partway
  through on the tasks most worth watching closely.
- **Diffs are committed**, not gitignored: after a run,
  `eval/case-studies/<task_id>/{vanilla,claudia}.diff` are real, readable
  copies of what each condition actually produced. `eval/runs/<batch>/`
  itself stays gitignored like always.

```sh
ITALY_REPO=~/projects/italy-rs ./eval/integration.sh   # runs gsplat-resample-01
./eval/eval.sh eval/runs/<batch>                       # fold the result into latest.md/json
```

## Output

- `eval/results/latest.json` / `eval/results/latest.md` — committed,
  regenerated by `eval/eval.sh`. Don't hand-edit these.
- `eval/runs/<batch>/<task>/<condition>/<trial>/` — gitignored raw
  artifacts per run: `transcript.ndjson` (full stream-json event log),
  `diff.patch`, `metrics.json`, `summary.json` (diff + final response text
  + delegation events, what the judge actually sees), `stderr.log`,
  `exit_code`. `eval/runs/<batch>/<task>/judge/<trial>.json` holds that
  trial's judge verdict for both conditions, real names restored.
- `python3 eval/propagate_readme.py` reads `latest.json` and, only if
  claudia's aggregate clears a margin (`--margin`, default `0.05`) over
  vanilla and isn't a regression from whatever's currently published,
  updates the `<!-- claudia:results:start/end -->` block in the top-level
  `README.md`. It refuses (loudly, nonzero exit) otherwise rather than
  silently overwriting a good number with a worse one.

## A known assumption worth checking on first run

`eval/lib/extract_summary.py` parses Claude Code's `stream-json` event
format defensively (best-effort, degrades to empty fields rather than
crashing) because the exact event shape isn't a stable public contract.
After your first `--smoke` run, it's worth opening one
`eval/runs/<batch>/*/transcript.ndjson` and confirming `final_response`
and `delegations` in the matching `summary.json` actually reflect what
happened — especially for the `delegation-*` tasks, since those checklist
items depend entirely on delegation events being extracted correctly.
