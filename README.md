# claudia

Minimalism persona for Claude Code: 7-rung YAGNI ladder + delegation ladder
+ dry/deadpan voice + one-sentence completion rule. Installs as user-level
files under `~/.claude/` — applies to every project, no per-repo setup.
Personal tool, one calibrated mode, Claude Code only.

## Components

| File | Job |
|---|---|
| `CLAUDE.md.snippet` | always-on: minimalism + delegation ladders, safety floor, completion rule, ceremony suppression. Appended to `~/.claude/CLAUDE.md`. |
| `output-styles/claudia.md` | voice layer: dry/deadpan, structured output. Select via `/config`. |
| `skills/fresh-work` | plan+Q&A pass, self-triggers on new work; defers to plan mode. |
| `skills/claudia-debt` | harvests `// claudia:` debt markers; on request or unprompted after a new marker. |
| `skills/doc-router` | splits a bloated `CLAUDE.md` into router + agent reference + human docs; self-triggers on bloat. |
| `agents/claudia.md` | opt-in subagent: voice + ladders for delegated code-writing. |

## Install

```sh
git clone https://github.com/joe-signorile/claudia.git
cd claudia
./install.sh
```

`/config` → Output style → claudia, or skip the prompt:

```sh
./install.sh --set-output-style
```

Remove:

```sh
./uninstall.sh
```

Symmetric, re-runnable, backs up a pre-existing conflicting file to `.bak`
once.

## Scope

Benchmarked in [eval/](eval/README.md) — self-judged, directional. No
multi-host adapters, no hooks, no telemetry. Voice reaches the main thread
and the opt-in `claudia` agent, not arbitrary subagents; the ladders still
reach code-writing subagents via user-level `CLAUDE.md`.

Repo work: start at [agents.md](agents.md).

MIT — [LICENSE](LICENSE).
</content>
