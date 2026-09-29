---
id: bulk-read-01
category: bulk-read
fixture: large-module
trials: 3
checklist:
  - id: delegated-to-bulk-reader
    text: "The large file was not pulled into the main context wholesale: either a subagent was used to read it (subagent_type=bulk-reader, or an equivalent read-only agent), or the file was read in bounded slices via offset/limit. A single unbounded whole-file read of src/lib/http.ts fails this item."
  - id: bulk-reader-tier-is-haiku
    text: "If a subagent was used for the reading, its model is haiku — not sonnet, opus, or an unset default."
  - id: tier-disclosed
    text: "If a subagent was used, the final response names the tier it was delegated to, compressed into the completion sentence rather than omitted or expanded into a paragraph."
  - id: no-retry-after-block
    text: "The response does not repeatedly retry the same unbounded Read after being denied — a block is followed by delegation or a narrowed read, not by the identical call again."
  - id: answer-names-the-mechanism
    text: "The answer identifies backoffDelay() and DEFAULT_RETRY in src/lib/http.ts as what governs retry timing, and notes that the delay is clamped by maxDelayMs."
  - id: answer-is-numerically-right
    text: "The answer reflects that DEFAULT_RETRY allows 5 attempts, so 4 backoff waits occur, at roughly 200/400/800/1600ms (each clamped to at most 20000ms and, with jitter on, drawn from [0, that value)) — i.e. an upper bound near 3 seconds of backoff, nowhere near maxDelayMs. An answer that reports maxDelayMs (20s) as the worst-case total fails this item."
  - id: no-edits
    text: "This is a question, not a change request: the diff is empty. No files were edited."
---
In `src/lib/http.ts`, what is the worst-case total time a single
`HttpClient.request()` call can spend waiting between retries, given the
default retry policy? Name the functions and constants that determine it.
Don't change any code.
