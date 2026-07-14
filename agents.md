# monkey-boy — agent reference

A Claude Code minimalism persona (YAGNI ladder + dry/deadpan voice),
distributed as user-level files under `~/.claude/`. There is no build,
no runtime, no source to compile — the repo is markdown artifacts plus
two POSIX shell installers.

## Doc map

| File | What | When |
|---|---|---|
| `agents.md` | This file — agent reference: inventory + invariants | Always, first |
| `README.md` | Human overview, install, scope | For human-facing prose |
| `CLAUDE.md` | Pure router, no content | — |

`CLAUDE.md.snippet` is not a doc — it is a shipped payload (see below).

## Shipped artifacts

- `CLAUDE.md.snippet` — the always-on core: the 7-rung minimalism ladder +
  ceremony suppression. Appended into the user's `~/.claude/CLAUDE.md`.
- `output-styles/monkey-boy.md` — the voice layer (dry/deadpan, structured
  output). `keep-coding-instructions: true`. Selected via `/config`.
- `skills/fresh-work/SKILL.md` — plan+Q&A pass, auto-triggers on genuinely
  new work; defers to built-in plan mode.
- `skills/monkey-boy-debt/SKILL.md` — read-only; harvests `// monkey-boy:`
  debt markers on request.
- `skills/doc-router/SKILL.md` — suggests the doc-router split (thin router +
  dense agent reference + human docs) when a project's `CLAUDE.md` is
  monolithic, or on request; TOON vs md by density. Advise-then-offer, gated.
- `agents/monkey-boy.md` — opt-in worker subagent carrying the voice +
  ladder into delegated code-writing.
- `install.sh` / `uninstall.sh` — copy artifacts into `~/.claude/` and
  append/strip the snippet block. Symmetric and re-runnable.
- `lib_dirs.sh` — shared config-dir discovery/selection, sourced by both
  scripts. Repo-local tooling only; never copied to `~/.claude/`, so it's
  not a shipped artifact and sits outside the four-place lockstep below.

## Invariants

- **Repo `CLAUDE.md` (router) ≠ shipped `CLAUDE.md.snippet`.** The snippet
  is a payload appended into the *user's* `~/.claude/CLAUDE.md`; the repo's
  own `CLAUDE.md` is context for working *on* this repo. Never merge or
  confuse them.
- **Adding a shipped artifact touches four places, in lockstep:**
  `install.sh` (`mkdir -p` + `backup_and_copy`), `uninstall.sh`
  (`remove_and_restore` + any `rmdir`), the README "What it does" list,
  and the inventory above.
- **Two marker conventions:**
  - `<!-- monkey-boy:start -->` / `<!-- monkey-boy:end -->` fence the
    snippet block — `install.sh` appends it, `uninstall.sh`'s awk strips
    it (and the blank line install prepended). Both scripts match these
    strings verbatim; don't reword them.
  - `// monkey-boy: <ceiling chosen> — upgrade if <trigger>` is the
    in-code debt marker the ladder leaves and the `monkey-boy-debt` skill
    harvests.
- **install/uninstall symmetry.** Install backs a differing dest up to
  `.bak` once (never clobbering an earlier backup); uninstall restores
  from `.bak`. Any new install step needs its inverse.
- **The ladder text is duplicated on purpose.** Full version in
  `CLAUDE.md.snippet` (source of truth); working summary in
  `agents/monkey-boy.md`; the output style references it rather than
  restating. Edit the snippet first, then keep the agent summary
  consistent.
- **Voice applies to the repo's own docs.** Dry/deadpan, no emoji, compact
  over verbose. These docs obey monkey-boy's own rules.

Keep this file updated alongside changes.
