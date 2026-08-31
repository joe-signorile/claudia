# claudia — agent reference

A Claude Code minimalism persona (YAGNI ladder + dry/deadpan voice),
distributed as user-level files under `~/.claude/`. There is no build,
no runtime, no source to compile — the repo is markdown artifacts plus
two POSIX shell installers.

## Doc map

| File | What | When |
|---|---|---|
| `agents.md` | This file — agent reference: inventory + invariants | Always, first |
| `README.md` | Facts: components, install, scope — not optimized for human readability | Repo overview |
| `CLAUDE.md` | Pure router, no content | — |

`CLAUDE.md.snippet` is not a doc — it is a shipped payload (see below).

## Shipped artifacts

- `CLAUDE.md.snippet` — the always-on core: minimalism + delegation
  ladders, safety floor, completion rule, ceremony suppression. Appended
  into the user's `~/.claude/CLAUDE.md`.
- `output-styles/claudia.md` — the voice layer (dry/deadpan, structured
  output). `keep-coding-instructions: true`. Selected via `/config`.
- `skills/fresh-work/SKILL.md` — plan+Q&A pass, auto-triggers on genuinely
  new work; defers to built-in plan mode.
- `skills/claudia-debt/SKILL.md` — read-only; harvests `// claudia:`
  debt markers on request, and unprompted at the end of any turn that left a
  new marker behind (folded into the one-sentence completion note as a
  clause; full-repo sweeps stay on-request).
- `skills/doc-router/SKILL.md` — splits an overloaded `CLAUDE.md` (thin
  router + dense agent reference + human docs) when a project shows real
  bloat, or on request; md by default, TOON only when the reference is
  predominantly uniform records. Gated on the bloat signal, but once the
  gate fires it performs the split directly — no advise-then-offer pause.
  If no `CLAUDE.md` exists yet, runs `init` first, then re-applies the gate.
- `agents/claudia.md` — opt-in worker subagent carrying the voice +
  ladder into delegated code-writing.
- `install.sh` / `uninstall.sh` — symlink artifacts into `~/.claude/` (one
  source of truth: the repo) and append/strip a marker block whose only
  content is an `@<repo>/CLAUDE.md.snippet` import line. Symmetric and
  re-runnable. Requires the repo to stay at a stable path — moving or
  deleting it breaks every linked install until re-run.
- `lib_dirs.sh` — shared config-dir discovery/selection, sourced by both
  scripts. Discovers `~/.claude`, `$CLAUDE_CONFIG_DIR`, sibling
  `~/.claude-*` dirs, `~/*/.claude*/` dirs one level down that contain both
  `CLAUDE.md` and `settings.json`, and any `CLAUDE_CONFIG_DIR=` assignment
  in a shell rc file. Repo-local tooling only; never copied to `~/.claude/`,
  so it's not a shipped artifact and sits outside the four-place lockstep
  below.
- `tests/install_test.sh`, `tests/uninstall_test.sh` — exercise install/
  uninstall in sandboxed `HOME` dirs. Dev-only, same as `lib_dirs.sh`: never
  copied to `~/.claude/`, outside the four-place lockstep below.
- `eval/` — reproducible eval harness comparing stock Claude Code against a
  real `install.sh`-seeded claudia install across a fixed task corpus,
  scored by a blinded LLM judge plus deterministic diff metrics. Repo-local
  tooling only, like `lib_dirs.sh` — never copied to `~/.claude/`. See
  `eval/README.md` for methodology and the self-bias disclosure.
  `eval/results/latest.{md,json}` are committed (regenerated output, never
  hand-edited); everything under `eval/runs/` is gitignored raw output.

## Invariants

- **Repo `CLAUDE.md` (router) ≠ shipped `CLAUDE.md.snippet`.** The snippet
  is a payload appended into the *user's* `~/.claude/CLAUDE.md`; the repo's
  own `CLAUDE.md` is context for working *on* this repo. Never merge or
  confuse them.
- **Adding a shipped artifact touches four places, in lockstep:**
  `install.sh` (`mkdir -p` + `link_and_backup`), `uninstall.sh`
  (`remove_and_restore` + any `rmdir`), the README "What it does" list,
  and the inventory above.
- **Two marker conventions:**
  - `<!-- claudia:start -->` / `<!-- claudia:end -->` fence the
    block — `install.sh` writes/rewrites a single `@<repo>/CLAUDE.md.snippet`
    import line between them (never pasted content), `uninstall.sh`'s awk
    strips the whole fenced span regardless of what's inside it (and the
    blank line install prepended). Both scripts match these strings
    verbatim; don't reword them.
  - `// claudia: <ceiling chosen> — upgrade if <trigger>` is the
    in-code debt marker the ladder leaves and the `claudia-debt` skill
    harvests.
- **install/uninstall symmetry.** Install backs a pre-existing non-symlink
  dest up to `.bak` once (never clobbering an earlier backup), then
  symlinks dest -> repo; uninstall removes the link and restores `.bak` if
  present. Any new install step needs its inverse.
- **The ladder text is duplicated on purpose.** Full version in
  `CLAUDE.md.snippet` (source of truth); working summary in
  `agents/claudia.md`; the output style references it rather than
  restating. Edit the snippet first, then keep the agent summary
  consistent. Applies to both ladders in that file — the 7-rung minimalism
  ladder and the delegation ladder (model-class tiering: haiku < sonnet <
  opus < fable/user) — same duplication rule, same two files. The output
  style (`output-styles/claudia.md`) must reference *both* ladders, not
  just minimalism — it's the artifact active every session, so a ladder
  missing from it effectively doesn't apply during planning even though the
  full text is sitting in CLAUDE.md context.
- **`keep-coding-instructions: true` is a binary switch, not selective.**
  Setting it keeps Claude Code's entire default system prompt (Doing tasks,
  Tone and style, etc.) and appends the output style after it; there's no
  way to keep the engineering-discipline instructions while dropping just
  the default Tone-and-style section. So the default tone guidance and
  claudia's terse voice both sit in context at once — that's expected,
  not a bug. The terseness payoff is in response length, not system-prompt
  size (which is fixed/cached regardless of output style).
- **Voice applies to the repo's own docs, `README.md` included.** Dry/
  deadpan, no emoji, compact over verbose, no human-comfort framing
  (taglines, images, attribution prose). This repo's `README.md` is
  *not* the "human docs" tier the generic doc-router pattern describes for
  target projects — that distinction is deliberate, not drift: don't
  re-humanize it to match the pattern.
- **The completion rule is one sentence, with exactly two exemptions.**
  Finished work ends in one short sentence — no approach summary, no
  rationale, no restating the diff. Exempt: (a) security findings,
  destructive/irreversible operations, and refusing/amending an instruction
  that would break something; (b) explanation the user explicitly asked
  for. Delegation-tier disclosure and new `claudia:` markers are *not*
  exempt — they compress into the sentence as a clause. That distinction is
  load-bearing, not stylistic: `delegation-trivial-01` and
  `delegation-escalate-01` score tier disclosure against the final response
  text, so wording that reads as "omit" instead of "compress" regresses
  those categories directly. Stated in `CLAUDE.md.snippet` (source of
  truth), `output-styles/claudia.md`, and `agents/claudia.md` — same
  three-file lockstep as the ladders.
- **Response length is measured continuously, not by checklist.**
  `eval/aggregate.py`'s `load_prose()` counts words in `summary.json`'s
  `final_response` with fenced code blocks stripped (verbatim content is
  never compressed, so counting it would score the wanted behaviour as
  verbosity), rolled up per task and per kind exactly like tokens.
  `voice-01`'s checklist is a floor guard only: a boolean "is it short"
  item saturates the moment both arms clear its threshold and then cannot
  show a gap in either direction — that is why the `voice` category read
  vanilla 95% / claudia 90% while claudia's replies were ~2x shorter.
  Quote the `prose` figures, not the `voice` row, for anything about
  output length.
- **Every skill/agent self-triggers on its own gate — none require an
  explicit ask.** `fresh-work` already worked this way; `doc-router` and
  `claudia-debt` were changed to match (was: advise-then-offer /
  on-request only). Each keeps its own gate (bloat signal, new marker) —
  this widens *when* it fires, not *what* it's allowed to touch unprompted.
  `doc-router` performs the split once gated, no wait for agreement;
  `claudia-debt` harvests only the file(s) just touched, not a full-repo
  sweep, unless asked. Stated in `CLAUDE.md.snippet` and the output style —
  keep both in sync with this if it changes again.
- **Eval corpus and README's Results section stay in sync.**
  `eval/tasks/*.md` is the source of truth for what's measured;
  `eval/results/latest.{md,json}` is regenerated output, never hand-edited;
  README's `<!-- claudia:results:start/end -->` block is written only by
  `eval/propagate_readme.py`, never by hand, and only updates when
  claudia's aggregate clears the stated margin over vanilla (and isn't a
  regression from what's currently published). If the task corpus changes,
  re-run `./eval/unit.sh && ./eval/eval.sh <batch>` before trusting a stale
  `latest.md`.
- **Fixture tasks and case studies are never averaged together.**
  `eval/aggregate.py`'s `task_kind()` classifies every task as `fixture`
  (a `fixture:` name that resolves under `eval/fixtures/`, 5-trial toy
  repo, mostly saturated at 100% by design — a regression guard, not a
  discriminator) or `case-study` (a real external repo, 1 trial, the
  actual claudia thesis). Both land in `by_kind` in `latest.json`; the old
  unweighted `aggregate`/`delta` fields are kept for continuity only and
  must never be the quoted number, since an n=1 case study's cache-read
  volume can be ~4 orders of magnitude a fixture's and would silently
  dominate any mean taken across both. `propagate_readme.py` publishes
  `by_kind["case-study"]`, never `aggregate` — if you add a new kind of
  task, `task_kind()` needs to classify it or this silently breaks.
- **`eval/` is split three ways.** `unit.sh` runs the synthetic-fixture
  corpus (throwaway repos, cheap, 5 trials/task, `--resume`-able).
  `integration.sh` runs a single hard, real roadmap task against a real
  external repo — which repo is derived per-task from the task's own
  `fixture:` field (default `$HOME/projects/<fixture>`, `EVAL_REPO`
  overrides), currently `italy-rs`, `instrumental`, and `rogue` — on its
  own git worktree/branch per condition, no budget cap, one trial,
  two-stage plan-then-execute session — a case study, not a statistical
  sample. `eval.sh` is the shared
  aggregate+report tail either one's batch dir feeds into; it has no
  orchestration logic of its own. Both writers use the identical
  `$BATCH_DIR/<task_id>/<condition>/<trial>/` artifact shape so
  `aggregate.py`/`report.py`/`judge.py` don't need to know which one
  produced a given task's data.
- **`eval/case-studies/` is committed; `eval/runs/` is not.** Raw
  transcripts/diffs under `eval/runs/<batch>/` are gitignored (large,
  disposable, regeneratable). `integration.sh` copies just the durable,
  human-readable diff per condition into `eval/case-studies/<task_id>/`,
  which *is* committed — that's what "get the diffs into docs" means here.
- **The eval's marker convention is distinct from the shipped one.**
  `<!-- claudia:results:start -->`/`...:end -->` (README, written by
  `propagate_readme.py`) is a separate fence from
  `<!-- claudia:start -->`/`...:end -->` (reserved for the
  `CLAUDE.md.snippet` @import payload) — don't collide the two or reuse one
  for the other's purpose.

Keep this file updated alongside changes.
