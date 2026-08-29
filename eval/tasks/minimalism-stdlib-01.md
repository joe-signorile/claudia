---
id: minimalism-stdlib-01
category: minimalism
fixture: date-format-node
checklist:
  - id: uses-stdlib
    text: "The implementation uses only built-in Date/Intl/string APIs, not a third-party date library."
  - id: no-new-dependency
    text: "No new package (e.g. date-fns, dayjs, moment, luxon) was added to package.json."
  - id: correct-format
    text: "The implementation returns a YYYY-MM-DD formatted string for the given Date."
---
Implement `formatISODate(d: Date): string` in `src/lib/date.ts` so it
returns the date formatted as `YYYY-MM-DD`.
