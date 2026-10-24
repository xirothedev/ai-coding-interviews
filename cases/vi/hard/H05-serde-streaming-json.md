# H05 — Zero-Copy Streaming JSON Deserializer & Buffer Boundary

[⬅️ Back to Hard Catalog](README.md) · [🏠 Master Hub](../../../README.md)

| Attribute                    | Details                                                                                                          |
| :--------------------------- | :--------------------------------------------------------------------------------------------------------------- |
| **Case ID**                  | `H05`                                                                                                            |
| **Difficulty Level**         | 🔴 **Hard** (`60–75 mins` — Senior / Staff Bar)                                                                  |
| **Task Archetype**           | Systems / Memory + Scale Optimization                                                                            |
| **Source GitHub Repository** | [`serde-rs/json`](https://github.com/serde-rs/json)                                                              |
| **Target Files**             | `src/read.rs`, `src/de.rs`, `tests/stream.rs`                                                                    |
| **Supported Languages**      | `Rust`                                                                                                           |
| **Hard Taxonomy Pillars**    | Pillar 2 (Streaming Buffer Scale) · Pillar 3 (Borrow-Checker Lifetimes) · Pillar 4 (Partial Read State Recovery) |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Source Repository & Pull Request (Confidential)

| Field                              | Value                                      |
| :--------------------------------- | :----------------------------------------- |
| **Repository**                     | `https://github.com/serde-rs/json`         |
| **Base SHA (pre-merge)**           | `fd6741f4b0b3fc90a58a6f578e33a9adc6403f3f` |
| **Merge SHA (reference solution)** | `4c81923102dccbf62a735499bbb9494b05dd7b79` |
| **Test Command**                   | `cargo test`                               |

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/serde-rs/json.git interview-workspace
cd interview-workspace
git checkout fd6741f4b0b3fc90a58a6f578e33a9adc6403f3f
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
cargo test
```

### Reproducibility Verification

- **Base SHA (`fd6741f4b0b3`)**: the test suite must contain at least one failing test related to the issue.
- **Merge SHA (`4c81923102dc`)**: the same tests must pass after checkout.

### Files Changed (Reference Solution)

- src/de.rs, src/read.rs

### Failing Tests to Enable

- Failing tests to enable/verify: tests/stream.rs. Run the test command to confirm red on Base SHA and green on Merge SHA.

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Production Bug Report: Streaming JSON Framing & Split Multi-Byte UTF-8 Over Chunked Readers
>
> Engineers streaming concatenated and newline-delimited JSON payloads over TCP sockets (`StreamDeserializer` backed by an `io::Read` stream) have reported two critical bugs in our Rust JSON library:
>
> 1. **Self-Delimiting Composite vs. Adjacent Scalar Framing in `StreamDeserializer`**:
>    - Valid self-delimiting JSON values (`{"a":1}{"b":2}`, `[1,2][3,4]`, `"hello""world"`) must parse cleanly back-to-back without requiring intervening whitespace.
>    - Conversely, non-delimited adjacent scalars (`123true`, `truefalse`, `null123`, `123"abc"`) are invalid JSON framing and **must be rejected** with a syntax error (`TrailingCharacters` / `ExpectedSomeValue`), whereas `123 true` (whitespace-separated) or `123[1]` (where `[` is a valid self-delimiting token after a number) must succeed.
>    - Calling `byte_offset()` on the stream must always report the exact byte index at the end of each deserialized value and upon reaching EOF.
> 2. **Multi-Byte UTF-8 Codepoints Split Across `io::Read` Chunk Boundaries**:
>    - When streaming from a network socket or chunked `io::Read` source where a single `read()` call yields only `1` or `2` bytes of a 3- or 4-byte UTF-8 sequence (e.g., `€` or `🦀` = `[0xF0, 0x9F, 0xA6, 0x80]`), the streaming reader falsely fails with `InvalidUnicodeCodePoint`.
>    - The reader must seamlessly accumulate bytes across arbitrary chunk boundaries and validate UTF-8 properly while preserving zero-copy borrowed string lifetimes (`'de`) when reading from in-memory slices.
>    - **Strict Safety Rule**: Introducing unsound `unsafe` blocks (such as transmuting scratch-buffer lifetimes `'s` to `'de`) is strictly forbidden.
>
> ### Acceptance Criteria
>
> 1. Locate the streaming deserializer and `io::Read` / slice reader implementations in the codebase, and uncomment any disabled streaming framing and chunk-boundary tests.
> 2. Fix `StreamDeserializer` post-value delimiter handling so self-delimiting composites succeed back-to-back, non-delimited scalars are rejected, and `byte_offset()` remains exact.
> 3. Fix streaming string parsing over `io::Read` so multi-byte UTF-8 characters split across arbitrary `read()` calls succeed without unsound lifetime transmutation.
> 4. Add a stress test using a custom `io::Read` wrapper that yields at most `N` bytes (`N = 1, 2, 3`) per `read()` call, verifying that streaming a mix of multi-byte emojis (`"🦀🚀"`), escaped UTF-16 surrogate pairs (`"\uD83E\uDD80"`), scalars, and objects produces identical results and `byte_offset()` positions as in-memory slice deserialization.

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Trusting the first plausible fix

- **What Naive AI Writes**: A minimal edit that makes the happy path pass but ignores the edge cases exercised by the real PR (`Return None after stream deserializer has failed`).
- **Why It Fails**: The PR touches `src/de.rs, src/read.rs, src/lib.rs`; a shallow change leaves the underlying defect (ordering, caching, type resolution, or retry semantics) in place, so hidden tests still fail.
- **Correct Fix**: Reproduce the failing tests on Base SHA, then implement the same behavior change as the merged PR (study its diff), including edge cases and invariants.

### Trap 2: Over-editing unrelated code

- **What Naive AI Writes**: Refactors surrounding modules "while at it", changing public APIs.
- **Why It Fails**: Breaks callers and the hidden regression tests; the reference solution is minimal and scoped to the PR's changed lines.
- **Correct Fix**: Limit edits to the files/lines indicated by the failing tests; keep diffs small and behavior-focused.

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Trace the current behavior in `src/de.rs, src/read.rs, src/lib.rs, tests/stream.rs` and identify why the failing tests fail on Base SHA."_
2. **Step 2 (`Plan`)**:
   - Reproduce with the test command; list the minimal files to change.
3. **Step 3 (`Prompt`)**:
   - Prompt 1: Implement the fix matching the merged PR's behavior, scoped to the failing tests.
   - Prompt 2: Add/adjust tests for edge cases (empty input, boundary values, error paths).
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Run the full test command; confirm all previously-failing tests pass and no regressions.

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

|   #   | Criterion                        | Strong Hire / Hire (`Score 3–4`)                                                                                                  | No Hire / Blind Vibe-Coder (`Score 1–2`)                                                            |
| :---: | :------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------- |
| **1** | **Problem Decomposition**        | Separates `StreamDeserializer` token framing in `src/de.rs` from byte buffering in `src/read.rs`.                                 | Pastes both files into AI and asks for a combined rewrite.                                          |
| **2** | **Prompt Context Quality**       | Explicitly forbids `unsafe` transmutation and points out the UTF-8 ASCII delimiter property (`0x22` / `0x5C` < `0x80`).           | Prompts _"Fix the borrow checker error in `read.rs`"_ and accepts `unsafe` code.                    |
| **3** | **Not Blindly Trusting AI**      | Rejects any `unsafe` lifetime cast or premature per-chunk `from_utf8` call.                                                       | Accepts `unsafe { mem::transmute(...) }` to make the compiler happy (**Automatic Veto / No Hire**). |
| **4** | **Code Reading Speed**           | Quickly grasps `Reference::Borrowed` vs `Reference::Copied` and `peek()` / `discard()` in `Read<'de>`.                            | Struggles to understand why `Read<'de>` has two lifetimes (`'de` and `'s`).                         |
| **5** | **Bug & Edge-Case Discovery**    | Tests `123true` (invalid), `123[1]` (valid), `{"a":1}{"b":2}` (valid), 1-byte chunked emojis, and `\uD83D\uDE00` surrogate pairs. | Only tests whitespace-separated JSON objects on in-memory slices.                                   |
| **6** | **Testing Before Claiming Done** | Writes the `ChunkedReader` 1-byte read test in `tests/stream.rs` and runs full `cargo test`.                                      | Only runs existing slice tests without testing `IoRead` with partial reads.                         |
| **7** | **Explaining Correctness**       | Explains UTF-8 byte encoding (`0xxxxxxx` vs `10xxxxxx` continuation bytes) and why `"`/`\` cannot occur mid-codepoint.            | Cannot explain why scanning for `b'"'` on raw bytes is safe in UTF-8.                               |

### Interviewer Probing Questions (Final 10 Minutes)

1. **Q**: _"Why is it safe to scan raw bytes for `b'"'` (`0x22`) or `b'\\'` (`0x5C`) before validating UTF-8? Couldn't the second or third byte of a multi-byte UTF-8 character happen to equal `0x22`?"_  
   **Expected Answer**: No! By design of UTF-8, all bytes of any multi-byte character have their high bit set (`>= 0x80`: leading bytes are `110xxxxx`, `1110xxxx`, `11110xxx`, and continuation bytes are `10xxxxxx`). ASCII characters (`0x00..0x7F`), including `"` (`0x22`) and `\` (`0x5C`), never appear anywhere inside a multi-byte character.
2. **Q**: _"Why can `SliceRead` return `Reference::Borrowed<'de>` while `IoRead` must return `Reference::Copied<'s>`?"_  
   **Expected Answer**: In `SliceRead<'de>`, the entire input byte slice lives for `'de` (outliving the deserialization call). In `IoRead`, bytes are read incrementally into `self.scratch`, which is cleared and reused on the next string field, so its borrow `'s` only lasts for the duration of the visitor call.
