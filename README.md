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
| `agents/bulk-reader.md` | haiku-pinned read-only summarizer: answers questions about large files without pulling them into the main context. |
| `hooks/read-guard.sh` | `PreToolUse` guard: denies whole-file `Read` (and `cat`/`head`/`tail`/`less`/`more`) past `CLAUDIA_READ_GUARD_LINES` (default 350; `0` off), redirecting to `bulk-reader`. Registered in `settings.json` at install. |
| `hooks/session-boot.sh` | `SessionStart` hook: injects a short claudia pre-flight reminder (delegation + skill self-triggering) into every new session. `CLAUDIA_SESSION_BOOT=0` disables it. Registered in `settings.json` at install. |

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
multi-host adapters, no telemetry. Voice reaches the main thread and the
opt-in `claudia` agent, not arbitrary subagents; the ladders still reach
code-writing subagents via user-level `CLAUDE.md`.

**Scope change:** claudia previously shipped no hooks. It now installs two,
both registered in `settings.json`, active in every project. The
`PreToolUse` read guard is real enforcement — the delegation ladder alone
is guidance the model can decline, the guard is not. The `SessionStart`
hook is not: it injects a short pre-flight reminder at the start of every
session so the ladder/skill-triggering norms stay fresh and prominent
independent of where they land in `CLAUDE.md`, but it can't force a
delegation decision — no hook can, short of something byte-checkable like
the read guard's line count. Both fail open on anything they can't
evaluate; `CLAUDIA_READ_GUARD_LINES=0` and `CLAUDIA_SESSION_BOOT=0` turn
each off independently. `./uninstall.sh` strips both registrations and
leaves any hooks claudia didn't install alone.

Repo work: start at [agents.md](agents.md).

MIT — [LICENSE](LICENSE).
</content>
