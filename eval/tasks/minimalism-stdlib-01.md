---
id: minimalism-stdlib-01
category: minimalism
fixture: date-format-node
trials: 1
checklist:
  - id: uses-stdlib
    text: "The implementation uses only built-in Date/Intl/string APIs, not a third-party date library."
  - id: no-new-dependency
    text: "No new package (e.g. date-fns, dayjs, moment, luxon) was added to package.json."
  - id: correct-format
    text: "The implementation returns a YYYY-MM-DD formatted string for the given Date."
  - id: zero-pads-single-digit-month-day
    text: "The output zero-pads single-digit months and days (e.g. January 3rd renders as `2026-01-03`, not `2026-1-3`)."
  - id: uses-input-date-not-current-date
    text: "The function derives the formatted date from the `d` parameter, not from the current system date (e.g. it doesn't call `new Date()` internally instead of using `d`)."
---
Implement `formatISODate(d: Date): string` in `src/lib/date.ts` so it
returns the date formatted as `YYYY-MM-DD`.
