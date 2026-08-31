---
name: doc-router
description: >
  Use when a project's CLAUDE.md has grown large or monolithic — mixing
  routing, agent-reference material (architecture, commands, invariants), and
  human prose in one always-loaded file — or when the user asks to restructure
  or split their docs ("set up a doc router", "my CLAUDE.md is huge", "split
  the agent docs out"). Do not use for a small, single-purpose CLAUDE.md, and
  do not raise it on every fresh project — suggesting the split where there is
  no bloat is anti-YAGNI.
---

Perform the doc-router split once gated (see Depth below): shrink an
overloaded always-loaded CLAUDE.md down to a thin router.

## The pattern

- **Router `CLAUDE.md`** — routes, holds no content. Names the agent reference
  as mandatory-first reading and points humans at their docs.
- **Agent reference** (`agents.md`; `agents.toon` only in the narrow case
  below) — the dense technical reference: architecture, commands, constants,
  invariants. Read first for any code work.
- **Human docs** (`README.md`) — overview, install, prose. Stays human-facing.

## No existing docs

If the project has no `CLAUDE.md` (or no docs at all), there's nothing yet
to route. Run the `init` skill first to generate baseline docs, then apply
the Gate below to the result.

## Gate

`CLAUDE.md` loads every session; a monolithic one taxes every turn with
reference material most turns don't need — hence gating this on real bloat,
not firing it on every project. Only raise this when there's a real signal:

- a monolithic `CLAUDE.md` mixing routing + reference + human prose, or
- roughly >150 lines of always-loaded content.

A short, single-purpose `CLAUDE.md` is already correct. Leave it alone —
suggesting a three-file split there is exactly the over-structuring the
minimalism ladder exists to prevent.

## Format: TOON vs Markdown

Markdown is the default. Choose by the *shape* of the reference, not the size
of the project.

- **Markdown** unless the test below passes. Agent references are mostly prose
  — invariants, rationale, gotchas — and TOON's own docs are explicit that for
  deeply nested or non-uniform data, compact alternatives win outright. There
  is also no repeated-key tax in markdown to recover in the first place, so the
  headline TOON-vs-JSON savings don't transfer to a doc file.
- **TOON** only when the reference is *predominantly* uniform records — many
  rows sharing one key set (a large symbol/command/module table), with the
  prose reduced to a thin wrapper around them. A big project whose reference is
  still mostly prose does not qualify.

Two costs to weigh before switching: spelling out the format inline costs
instruction overhead that erases the savings at small sizes, and omitting it
leaves a future session inferring the syntax. Separately, don't extend this to
tool output — TOON measurably degrades multi-turn agentic accuracy and
parallel tool-call handling.

claudia applied this rule to its own repo and chose md.

## Depth

Trigger on the gate above without waiting to be asked — no advise-then-offer
pause. State briefly that the split is happening and why (the gate signal
that fired), then do it:

1. Extract the reference material out of `CLAUDE.md` into the agent reference
   (TOON or md per the rule above).
2. Reduce `CLAUDE.md` to a router: a line stating it holds no content, a
   "read the agent reference first" directive, and a small table mapping each
   doc to when to read it.
3. Keep `README.md` (or equivalent) human-facing.

Voice and anti-ceremony still apply: dry, compact, no restated plan, no nag.
