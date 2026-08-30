---
id: minimalism-oneliner-01
category: minimalism
fixture: array-utils
trials: 1
checklist:
  - id: no-new-dependency
    text: "No new package (e.g. lodash) was added to package.json to implement chunk."
  - id: single-function
    text: "The implementation is a small, self-contained function in the existing file, not spread across new helper files."
  - id: correct-behavior
    text: "The implementation correctly splits an array into chunks of the given size, including a shorter final chunk."
  - id: does-not-mutate-input
    text: "chunk does not mutate the input array (e.g., it doesn't use splice/shift on `arr` in place)."
  - id: handles-non-positive-size
    text: "chunk avoids looping forever or crashing when `size` is 0 or negative (e.g., by guarding against it or throwing a clear error)."
---
Implement `chunk<T>(arr: T[], size: number): T[][]` in
`src/lib/arrayUtils.ts`. It should split `arr` into consecutive chunks of
length `size`, with the last chunk shorter if the array doesn't divide
evenly.
