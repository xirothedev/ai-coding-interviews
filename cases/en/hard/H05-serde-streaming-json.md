# H05 — Zero-Copy Streaming JSON Deserializer & Buffer Boundary

> 🌐 Language: **English** · <a href="vi/H05-serde-streaming-json">Tiếng Việt</a>

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

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/serde-rs/json.git serde-json-interview
cd serde-json-interview
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
cargo test --test stream
```

### Seeded Defects to Inject Before the Session

1. **Bug 1 (`StreamDeserializer` Adjacent Scalar / Self-Delimiting Framing Bug)**: In `src/de.rs` (`StreamDeserializer::next`), alter the post-value delimiter check so that either self-delimiting adjacent composites (`{"a":1}{"b":2}` or `[1][2]`) falsely fail with `ErrorCode::TrailingCharacters`, OR adjacent non-delimited scalars (`123true` or `123"abc"`) are erroneously accepted without whitespace!
2. **Bug 2 (Multi-Byte UTF-8 Split Across `IoRead` Chunk Refill)**: In `src/read.rs` (`IoRead::parse_str`), validate UTF-8 per read chunk in a way that fails with `ErrorCode::InvalidUnicodeCodePoint` when an `io::Read` implementation splits a 3- or 4-byte UTF-8 character (like `€` or `🦀`) across two consecutive `read()` calls.

---

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

### Trap 1: Trying to Return `Reference::Borrowed<'de>` from `IoRead`'s Scratch Buffer

- **What Naive AI Writes**:
  - The AI sees `Reference::Borrowed` in `SliceRead` and tries to return `Reference::Borrowed(str_from_scratch)` in `IoRead`, hits Rust compiler error `lifetime may not live long enough ('s vs 'de)`, and then proposes:
    ```rust
    // AI HALLUCINATION - UNSOUND!
    unsafe { std::mem::transmute::<&'s str, &'de str>(s) }
    ```
- **Why It Fails**: `IoRead` clears `self.scratch` on the very next JSON string token! Returning `Reference::Borrowed<'de>` from `IoRead` causes a **use-after-free / buffer aliasing bug** if the caller deserializes a `&'de str`! `IoRead` MUST return `Reference::Copied(&'s str)` so Serde copies the string into an owned `String`.

### Trap 2: Calling `std::str::from_utf8` on Incomplete Multi-Byte Chunks

- **What Naive AI Writes**:
  - Validates `std::str::from_utf8(chunk)` immediately after each `read()` call and maps any `Err(_)` to `ErrorCode::InvalidUnicodeCodePoint`.
- **Why It Fails**: When `chunk` ends with `[0xF0, 0x9F]` (the first 2 bytes of `🦀`), `from_utf8` returns `Err(e)` where `e.error_len()` is `None` (indicating up to 3 trailing bytes are an incomplete multi-byte character waiting for the next `read()`, NOT invalid UTF-8!).
- **Correct Fix**: either append raw bytes into `scratch` up to the closing unescaped `"` or backslash `\` (which are single-byte ASCII `< 0x80` and can never appear as continuation bytes `0x80..0xBF` of a multi-byte UTF-8 sequence!) and validate `str::from_utf8(&self.scratch)` once the complete ASCII-delimited segment is buffered!

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code yet. Read `src/read.rs` and `src/de.rs`. Explain: (1) the difference between `'de` and `'s` in `Reference<'de, 's, str>`, (2) why ASCII bytes `"` (`0x22`) and `\` (`0x5C`) can never appear inside a multi-byte UTF-8 character, and (3) how `StreamDeserializer::next` checks for trailing characters after a scalar vs an object/array."_
2. **Step 2 (`Plan`)**:
   - Candidate notes the fundamental UTF-8 self-synchronizing property: ASCII bytes (`0x00..0x7F`) never appear as trailing bytes of multi-byte UTF-8 codepoints (`0x80..0xFF`). Therefore, scanning byte-by-byte into `scratch` until `"` or `\` and only running UTF-8 validation on complete segments between escapes never splits a multi-byte character!
3. **Step 3 (`Prompt`)**:
   - Prompt 1: Fix `StreamDeserializer::next()` lookahead delimiter check (`eat_char` only when needed; require whitespace/EOF/self-delimiter after numbers/booleans/null).
   - Prompt 2: Fix `IoRead::parse_str` to buffer into `scratch` up to ASCII delimiters before validating UTF-8, returning `Reference::Copied`.
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Verify zero `unsafe` blocks were added; write `ChunkedReader` test with 1-byte reads in `tests/stream.rs` and run `cargo test`.

---

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
