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

Suggest — and on request perform — the doc-router split: shrink an overloaded
always-loaded CLAUDE.md down to a thin router.

## The pattern

- **Router `CLAUDE.md`** — routes, holds no content. Names the agent reference
  as mandatory-first reading and points humans at their docs.
- **Agent reference** (`agents.toon` or `agents.md`) — the dense technical
  reference: architecture, commands, constants, invariants. Read first for any
  code work.
- **Human docs** (`README.md`) — overview, install, prose. Stays human-facing.

Why it's a minimalism move, not added ceremony: `CLAUDE.md` is loaded every
session. A monolithic one taxes every turn with reference material most turns
don't need. The router keeps the always-on context tiny and moves the dense
reference into a file read only when the work calls for it. That is why this is
gated on real bloat — see below.

## No existing docs

If the project has no `CLAUDE.md` (or no docs at all), there's nothing yet
to route. Run the `init` skill first to generate baseline docs, then apply
the Gate below to the result.

## Gate

Only raise this when there's a real signal:

- a monolithic `CLAUDE.md` mixing routing + reference + human prose, or
- roughly >150 lines of always-loaded content.

A short, single-purpose `CLAUDE.md` is already correct. Leave it alone —
suggesting a three-file split there is exactly the over-structuring the
minimalism ladder exists to prevent.

## Format: TOON vs Markdown

Choose by whether density pays off:

- **TOON** when the project is large or has compiled source with many symbols,
  commands, and modules — the token savings are real at that size. TOON packs
  typed tables (`commands[]{name,cmd,notes}`, `rules[]`, `stack[]{name,version}`)
  far denser than prose. Name the format and point the user at it; don't inline
  a full spec here.
- **Markdown** when the project is small or doc-only — density gains are
  marginal and md is more maintainable. claudia applied this same rule to
  its own repo and chose md.

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
