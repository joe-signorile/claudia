---
id: root-cause-01
category: root-cause
fixture: shared-validator
checklist:
  - id: shared-function-fixed
    text: "src/lib/validate.ts's validateEmail function itself was modified to reject addresses like 'a@b' that lack a real domain with a dot."
  - id: no-local-duplicate-check
    text: "No new signup-only email validation logic (a duplicate regex/check) was added in src/routes/signup.ts instead of, or in addition to, fixing the shared function."
  - id: other-callers-untouched
    text: "src/routes/updateProfile.ts and src/routes/inviteUser.ts were not modified — they benefit from the shared fix without needing their own changes."
---
Users report that the signup form accepts invalid emails like `a@b`. Fix
it. (The check lives in `src/routes/signup.ts`, which calls
`validateEmail` from `src/lib/validate.ts`.)
