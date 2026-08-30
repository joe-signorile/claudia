# claudia

<img src="claudia.webp" width="80" height="80" alt="claudia" align="left">

> Minimalism-first persona for Claude Code.

<!-- claudia:results:start -->
<!-- claudia:results:delta=0.33333333333333337 -->
## Results

Claudia's minimalism/safety/delegation checklist pass-rate beat stock Claude Code by 33pp (50% -> 83%) across 16 tasks, 5 trials each, both pinned to `sonnet`. Judge is Claude itself — see [eval/README.md](eval/README.md#self-bias) for that caveat and full methodology, plus how to reproduce this run yourself.

_Last measured: 2026-08-30._
<!-- claudia:results:end -->


A YAGNI ladder that runs before any code is written, plus a dry/deadpan voice
layer on top. It installs as user-level files under `~/.claude/`, so it applies
across every project with no per-repo setup. A personal tool, published as-is:
one calibrated mode, Claude Code only, no other agent hosts.

## What it does

Six shipped pieces, each with one job:

- **`CLAUDE.md.snippet`** — always-on core, appended to `~/.claude/CLAUDE.md`:
  7-rung minimalism ladder (exist? → reuse → stdlib → platform → dependency →
  one-liner → minimal code), a model-tier delegation ladder, a safety floor
  that's never simplified away, ceremony suppression. No selection needed.
- **`output-styles/claudia.md`** — the voice layer: dry, deadpan, technical;
  compact key:value/tabular output over prose for structured content.
  Selected once per machine via `/config`.
- **`skills/fresh-work`** — auto-triggers on genuinely new work; runs a
  plan+Q&A pass before coding. Defers to built-in plan mode when active.
- **`skills/claudia-debt`** — harvests `// claudia:` debt markers and flags
  any missing an upgrade trigger. Read-only; on request, or unprompted at
  the end of a turn that just added a marker.
- **`skills/doc-router`** — splits a monolithic `CLAUDE.md` into router +
  agent reference + human docs. Gated on real bloat; once gated, performs
  the split directly.
- **`agents/claudia.md`** — opt-in worker subagent carrying the voice and
  ladder into delegated code-writing.

## Install

```sh
git clone https://github.com/joe-signorile/claudia.git
cd claudia
./install.sh
```

Then run `/config` in Claude Code and select **Output style → claudia**.

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

Benchmarked against stock Claude Code on a fixed task corpus (`eval/`) — see
[Results](#results) above, if present, and [eval/README.md](eval/README.md)
for methodology, numbers, and the self-judging caveat (the judge is Claude
itself; read results as directional). No multi-host adapters
(Cursor/Windsurf/Gemini/Cline), no hooks, no telemetry — nothing here phones
home. One honest limit: the voice reaches the main thread and the opt-in
`claudia` agent but can't be injected into arbitrary subagents (Claude Code
exposes no hook for it); the always-on ladder still reaches code-writing
subagents through the user-level `CLAUDE.md`.

Working on this repo? `CLAUDE.md` is a doc router — start at
[agents.md](agents.md) for the artifact inventory and invariants.

## Credits

- [caveman](https://github.com/JuliusBrussee/caveman) — terse-output principle
- [ponytail](https://github.com/DietrichGebert/ponytail) — YAGNI ladder and its safety floor
- [Zed](https://zed.dev/blog/on-programming-with-agents) — "know your task first"
- [Robert Martin](https://en.wikipedia.org/wiki/Robert_C._Martin) — Clean Code, Clean Architecture
- [SudoJoe](https://www.linkedin.com/in/joe-signorile-ab60695b) — it's me, Joe

MIT — see [LICENSE](LICENSE).
