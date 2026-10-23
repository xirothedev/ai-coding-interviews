# H05 — Zero-Copy Streaming JSON Deserializer & Buffer Boundary

[⬅️ Back to Hard Catalog](README.md) · [🏠 Master Hub](../../README.md)

| Attribute | Details |
| :--- | :--- |
| **Case ID** | `H05` |
| **Difficulty Level** | 🔴 **Hard** (`60–75 mins` — Senior / Staff Bar) |
| **Task Archetype** | Systems / Memory + Scale Optimization |
| **Source GitHub Repository** | [`serde-rs/json`](https://github.com/serde-rs/json) |
| **Target Files** | `src/read.rs`, `src/de.rs`, `tests/stream.rs` |
| **Supported Languages** | `Rust` |
| **Hard Taxonomy Pillars** | Pillar 2 (Streaming Buffer Scale) · Pillar 3 (Borrow-Checker Lifetimes) · Pillar 4 (Partial Read State Recovery) |

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

> ### Welcome to Your AI-Enabled SWE Coding Interview
> You are working inside `serde_json`, Rust's foundational JSON serialization library. You have full access to the AI Assistant and `cargo test`. Remember: **introducing unsound `unsafe` blocks (such as lifetime transmutation) is strictly prohibited**.
>
> ### Problem Context
> Engineers streaming newline-delimited and concatenated JSON over TCP sockets (`serde_json::StreamDeserializer` backed by `IoRead<R>`) have reported two critical bugs:
> 1. **Streaming Framing Invariant (`StreamDeserializer` in `src/de.rs`)**:
>    - Valid self-delimiting JSON composites (`{"a":1}{"b":2}`, `[1,2][3,4]`, `"hello""world"`) must parse cleanly back-to-back without requiring whitespace between them.
>    - Invalid non-delimited JSON scalars (`123true`, `truefalse`, `null123`) MUST be rejected with a syntax error (`TrailingCharacters` / `ExpectedSomeValue`), whereas `123 true` (separated by whitespace) or `123[1]` (`[` is a valid self-delimiter after a number) must succeed!
>    - `stream.byte_offset()` must return the exact byte index at the end of each item and upon EOF.
> 2. **Multi-Byte UTF-8 Split Across TCP/Chunk Boundaries (`IoRead` in `src/read.rs`)**:
>    - When reading from a buffered network socket or chunked reader where a single `read()` call yields only `1` or `2` bytes of a 4-byte UTF-8 sequence (e.g., `🦀` = `[0xF0, 0x9F, 0xA6, 0x80]`), `IoRead` must seamlessly accumulate bytes into its scratch buffer and validate the complete UTF-8 sequence without corrupting lifetimes or rejecting valid UTF-8.
>
> ### Your Tasks
> 1. **Explore & Trace**: Inspect the `Read<'de>` trait in `src/read.rs` (`SliceRead`, `StrRead`, `IoRead`, `Reference<'de, 's, T>`) and `StreamDeserializer` in `src/de.rs`.
> 2. **Run & Uncomment Tests**: Run `cargo test --test stream` and uncomment the failing framing and chunk-split tests.
> 3. **Fix `StreamDeserializer` Framing & `IoRead` Chunked UTF-8 Parsing**: Fix both defects using safe Rust (or existing verified invariants in `src/read.rs`) while maintaining zero-copy `Reference::Borrowed<'de>` for `SliceRead`.
> 4. **Write a `ChunkedReader` Stress Test**: In `tests/stream.rs`, implement a `ChunkedReader<R>` wrapper that returns at most `N` bytes (`N = 1, 2, 3`) per `io::Read::read()` call, and verify that streaming a mix of emojis (`"🦀🚀"`), escaped surrogates (`"\uD83E\uDD80"`), numbers, and objects yields identical results and `byte_offset()` values as `SliceRead`.

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
   > *"Do not write code yet. Read `src/read.rs` and `src/de.rs`. Explain: (1) the difference between `'de` and `'s` in `Reference<'de, 's, str>`, (2) why ASCII bytes `"` (`0x22`) and `\` (`0x5C`) can never appear inside a multi-byte UTF-8 character, and (3) how `StreamDeserializer::next` checks for trailing characters after a scalar vs an object/array."*
2. **Step 2 (`Plan`)**:
   - Candidate notes the fundamental UTF-8 self-synchronizing property: ASCII bytes (`0x00..0x7F`) never appear as trailing bytes of multi-byte UTF-8 codepoints (`0x80..0xFF`). Therefore, scanning byte-by-byte into `scratch` until `"` or `\` and only running UTF-8 validation on complete segments between escapes never splits a multi-byte character!
3. **Step 3 (`Prompt`)**:
   - Prompt 1: Fix `StreamDeserializer::next()` lookahead delimiter check (`eat_char` only when needed; require whitespace/EOF/self-delimiter after numbers/booleans/null).
   - Prompt 2: Fix `IoRead::parse_str` to buffer into `scratch` up to ASCII delimiters before validating UTF-8, returning `Reference::Copied`.
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Verify zero `unsafe` blocks were added; write `ChunkedReader` test with 1-byte reads in `tests/stream.rs` and run `cargo test`.

---

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

| # | Criterion | Strong Hire / Hire (`Score 3–4`) | No Hire / Blind Vibe-Coder (`Score 1–2`) |
| :-: | :--- | :--- | :--- |
| **1** | **Problem Decomposition** | Separates `StreamDeserializer` token framing in `src/de.rs` from byte buffering in `src/read.rs`. | Pastes both files into AI and asks for a combined rewrite. |
| **2** | **Prompt Context Quality** | Explicitly forbids `unsafe` transmutation and points out the UTF-8 ASCII delimiter property (`0x22` / `0x5C` < `0x80`). | Prompts *"Fix the borrow checker error in `read.rs`"* and accepts `unsafe` code. |
| **3** | **Not Blindly Trusting AI** | Rejects any `unsafe` lifetime cast or premature per-chunk `from_utf8` call. | Accepts `unsafe { mem::transmute(...) }` to make the compiler happy (**Automatic Veto / No Hire**). |
| **4** | **Code Reading Speed** | Quickly grasps `Reference::Borrowed` vs `Reference::Copied` and `peek()` / `discard()` in `Read<'de>`. | Struggles to understand why `Read<'de>` has two lifetimes (`'de` and `'s`). |
| **5** | **Bug & Edge-Case Discovery** | Tests `123true` (invalid), `123[1]` (valid), `{"a":1}{"b":2}` (valid), 1-byte chunked emojis, and `\uD83D\uDE00` surrogate pairs. | Only tests whitespace-separated JSON objects on in-memory slices. |
| **6** | **Testing Before Claiming Done** | Writes the `ChunkedReader` 1-byte read test in `tests/stream.rs` and runs full `cargo test`. | Only runs existing slice tests without testing `IoRead` with partial reads. |
| **7** | **Explaining Correctness** | Explains UTF-8 byte encoding (`0xxxxxxx` vs `10xxxxxx` continuation bytes) and why `"`/`\` cannot occur mid-codepoint. | Cannot explain why scanning for `b'"'` on raw bytes is safe in UTF-8. |

### Interviewer Probing Questions (Final 10 Minutes)
1. **Q**: *"Why is it safe to scan raw bytes for `b'"'` (`0x22`) or `b'\\'` (`0x5C`) before validating UTF-8? Couldn't the second or third byte of a multi-byte UTF-8 character happen to equal `0x22`?"*  
   **Expected Answer**: No! By design of UTF-8, all bytes of any multi-byte character have their high bit set (`>= 0x80`: leading bytes are `110xxxxx`, `1110xxxx`, `11110xxx`, and continuation bytes are `10xxxxxx`). ASCII characters (`0x00..0x7F`), including `"` (`0x22`) and `\` (`0x5C`), never appear anywhere inside a multi-byte character.
2. **Q**: *"Why can `SliceRead` return `Reference::Borrowed<'de>` while `IoRead` must return `Reference::Copied<'s>`?"*  
   **Expected Answer**: In `SliceRead<'de>`, the entire input byte slice lives for `'de` (outliving the deserialization call). In `IoRead`, bytes are read incrementally into `self.scratch`, which is cleared and reused on the next string field, so its borrow `'s` only lasts for the duration of the visitor call.
