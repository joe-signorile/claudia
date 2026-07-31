# monkey-boy

<img src="mb.webp" width="80" height="80" alt="monkey-boy" align="left">

> Minimalism-first persona for Claude Code.

A YAGNI ladder that runs before any code is written, plus a dry/deadpan voice
layer on top. It installs as user-level files under `~/.claude/`, so it applies
across every project with no per-repo setup. A personal tool, published as-is:
one calibrated mode, Claude Code only, no other agent hosts.

## What it does

Six shipped pieces, each with one job:

- **`CLAUDE.md.snippet`** — the always-on core, appended to your
  `~/.claude/CLAUDE.md`: the 7-rung minimalism ladder (does this need to exist →
  reuse → stdlib → platform → dependency → one-liner → minimal code), a
  delegation ladder for which model class should do the work (haiku up
  through opus, with fable/asking-the-user as the last resort), a safety
  floor that's never simplified away, and ceremony suppression. Loaded every
  session, no selection needed.
- **`output-styles/monkey-boy.md`** — the voice layer: dry, deadpan, technical,
  with a preference for compact key:value/tabular output over prose when the
  content is structured. Selected once per machine via `/config`.
- **`skills/fresh-work`** — auto-triggers on genuinely new work (a new feature,
  "build me a...") and runs a plan+Q&A pass before coding. Defers to Claude
  Code's built-in plan mode when it's already active.
- **`skills/monkey-boy-debt`** — on request, harvests the `// monkey-boy:` debt
  markers the ladder leaves on deliberate simplifications and flags any missing
  an upgrade trigger. Read-only.
- **`skills/doc-router`** — when a project's `CLAUDE.md` has grown monolithic,
  suggests splitting it into a thin router + a dense agent reference + human
  docs, and offers to do the migration. Gated on real bloat, not fired at every
  project.
- **`agents/monkey-boy.md`** — an opt-in worker subagent that carries the voice
  and ladder into delegated code-writing.

## Install

```sh
git clone https://github.com/joe-signorile/monkey-boy.git
cd monkey-boy
./install.sh
```

Then run `/config` in Claude Code and select **Output style → monkey-boy**.

To skip the `/config` step and write the setting directly:

```sh
./install.sh --set-output-style
```

To remove everything (files plus the `CLAUDE.md` block):

```sh
./uninstall.sh
```

Install and uninstall are symmetric and safe to re-run; a differing existing
file is backed up to `.bak` once and restored on uninstall.

## Scope

No benchmarks, no measured token/LOC numbers, no multi-host adapters
(Cursor/Windsurf/Gemini/Cline), no hooks, no telemetry — nothing here phones
home. One honest limit: the voice reaches the main thread and the opt-in
`monkey-boy` agent but can't be injected into arbitrary subagents (Claude Code
exposes no hook for it); the always-on ladder still reaches code-writing
subagents through the user-level `CLAUDE.md`.

Working on this repo? `CLAUDE.md` is a doc router — start at
[agents.md](agents.md) for the artifact inventory and invariants.

## Credits

An original work, inspired by and credited to
[caveman](https://github.com/JuliusBrussee/caveman) (the terse-output
principle), [ponytail](https://github.com/DietrichGebert/ponytail) (the YAGNI
ladder and its safety floor), and
[Zed's "know your task first" philosophy](https://zed.dev/blog/on-programming-with-agents).

[SudoJoe](https://www.linkedin.com/in/joe-signorile-ab60695b) — Its me, Joe.

[Robert Martin](https://en.wikipedia.org/wiki/Robert_C._Martin) (Clean Code,
Clean Architecture).

MIT — see [LICENSE](LICENSE).
