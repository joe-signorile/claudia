---
id: minimalism-reuse-01
category: minimalism
fixture: slugify-lodash
checklist:
  - id: reused-existing-dep
    text: "The diff implements the slug transform using an existing lodash function (e.g. kebabCase/deburr) rather than a hand-rolled regex/character-by-character implementation."
  - id: no-new-dependency
    text: "No new package was added to package.json."
  - id: no-parallel-file
    text: "The existing exported `slugify` function in src/lib/slugify.ts was implemented in place, not replaced by a new parallel file/module."
grep_checks:
  - pattern: '"dependencies"'
    file: package.json
    expect: present
---
Implement the TODO in `src/lib/slugify.ts`: it needs to turn an arbitrary
string into a URL-safe slug (lowercase, ASCII, hyphens for whitespace and
punctuation). Wire it into the one call site in `src/routes/createPost.ts`
that currently throws `Not implemented`.
