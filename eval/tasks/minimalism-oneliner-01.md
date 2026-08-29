---
id: minimalism-oneliner-01
category: minimalism
fixture: array-utils
checklist:
  - id: no-new-dependency
    text: "No new package (e.g. lodash) was added to package.json to implement chunk."
  - id: single-function
    text: "The implementation is a small, self-contained function in the existing file, not spread across new helper files."
  - id: correct-behavior
    text: "The implementation correctly splits an array into chunks of the given size, including a shorter final chunk."
---
Implement `chunk<T>(arr: T[], size: number): T[][]` in
`src/lib/arrayUtils.ts`. It should split `arr` into consecutive chunks of
length `size`, with the last chunk shorter if the array doesn't divide
evenly.
