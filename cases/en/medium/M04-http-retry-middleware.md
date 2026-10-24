# M04 — HTTP Retry Middleware & Exponential Backoff Jitter

[⬅️ Back to Medium Catalog](README.md) · [🏠 Master Hub](../../../README.md)

| Attribute                    | Details                                                                                                                                                        |
| :--------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Case ID**                  | `M04`                                                                                                                                                          |
| **Difficulty Level**         | 🟡 **Medium** (`45–60 mins` — Standard SWE Bar)                                                                                                                |
| **Task Archetype**           | Bugfix + Feature Extension                                                                                                                                     |
| **Source GitHub Repository** | [`sindresorhus/ky`](https://github.com/sindresorhus/ky) (TypeScript) · [`encode/httpx`](https://github.com/encode/httpx) (Python)                              |
| **Target Files**             | `source/core/Ky.ts`, `source/core/retry-timing.ts`, `source/types/retry.ts`, `test/retry.ts`, `test/retry-timing.ts`, `test/retry-decisions.ts`                |
| **Supported Languages**      | `TypeScript`, `Python`, `Go`                                                                                                                                   |
| **Primary AI Traps**         | `parseInt` on HTTP-date `Retry-After` header (`"Wed, 21 Oct..."`) · Retrying `POST` without `Idempotency-Key` · Re-sending a consumed stream body as `0` bytes |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Source Repository & Pull Request (Confidential)

| Field                              | Value                                      |
| :--------------------------------- | :----------------------------------------- |
| **Repository**                     | `https://github.com/sindresorhus/ky`       |
| **Base SHA (pre-merge)**           | `06375efbacfc1bdc96f7a4de7560684b765e1274` |
| **Merge SHA (reference solution)** | `3419113b48e034fdcf8fa6bd3be3da7b3d0d758f` |
| **Test Command**                   | `npm test`                                 |

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/sindresorhus/ky.git interview-workspace
cd interview-workspace
git checkout 06375efbacfc1bdc96f7a4de7560684b765e1274
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
npm test
```

### Reproducibility Verification

- **Base SHA (`06375efbacfc`)**: the test suite must contain at least one failing test related to the issue.
- **Merge SHA (`3419113b48e0`)**: the same tests must pass after checkout.

### Files Changed (Reference Solution)

- source/core/Ky.ts, source/core/retry-timing.ts, source/types/retry.ts

### Failing Tests to Enable

- Failing tests to enable/verify: test/retry.ts, test/main.ts. Run the test command to confirm red on Base SHA and green on Merge SHA.

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Bug Report: HTTP Retry Middleware Reliability
>
> Production services using our HTTP retry logic hit reliability issues during an upstream outage. The retry engine must correctly interpret server-provided retry timing, guard non-idempotent requests, and avoid unsafe retries.
>
> ### Requirements
>
> - Parse the retry timing header in both supported formats (delay-seconds and HTTP-date), clamping past dates to zero and aborting without sleeping when the delay exceeds the configured maximum.
> - Only retry safe/idempotent methods by default; non-idempotent methods require an explicit idempotency key.
> - Use full-jitter exponential backoff when no server timing is provided, with an injectable random function for deterministic tests.
> - Do not retry requests whose body cannot be replayed.
>
> ### Acceptance Criteria
>
> 1. Trace retry eligibility and delay calculation across the client and retry modules.
> 2. Implement header parsing, idempotency guard, and backoff with injectable clock/random functions.
> 3. Verify edge cases: past dates, oversized delays, case-insensitive idempotency keys, and locked streams.

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Trusting the first plausible fix

- **What Naive AI Writes**: A minimal edit that makes the happy path pass but ignores the edge cases exercised by the real PR (`Improve Retry-After handling`).
- **Why It Fails**: The PR touches `source/core/Ky.ts, source/core/retry-timing.ts, source/types/retry.ts`; a shallow change leaves the underlying defect (ordering, caching, type resolution, or retry semantics) in place, so hidden tests still fail.
- **Correct Fix**: Reproduce the failing tests on Base SHA, then implement the same behavior change as the merged PR (study its diff), including edge cases and invariants.

### Trap 2: Over-editing unrelated code

- **What Naive AI Writes**: Refactors surrounding modules "while at it", changing public APIs.
- **Why It Fails**: Breaks callers and the hidden regression tests; the reference solution is minimal and scoped to the PR's changed lines.
- **Correct Fix**: Limit edits to the files/lines indicated by the failing tests; keep diffs small and behavior-focused.

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Trace the current behavior in `source/core/Ky.ts, source/core/retry-timing.ts, source/types/retry.ts, test/retry.ts, test/main.ts` and identify why the failing tests fail on Base SHA."_
2. **Step 2 (`Plan`)**:
   - Reproduce with the test command; list the minimal files to change.
3. **Step 3 (`Prompt`)**:
   - Prompt 1: Implement the fix matching the merged PR's behavior, scoped to the failing tests.
   - Prompt 2: Add/adjust tests for edge cases (empty input, boundary values, error paths).
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Run the full test command; confirm all previously-failing tests pass and no regressions.

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

|   #   | Criterion                        | Strong Hire / Hire (`Score 3–4`)                                                                                                                                    | No Hire / Blind Vibe-Coder (`Score 1–2`)                                                                                                         |
| :---: | :------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------ | :----------------------------------------------------------------------------------------------------------------------------------------------- |
| **1** | **Problem Decomposition**        | Extracts pure functions for `parseRetryAfter`, `calculateBackoff`, and `isRetryableRequest`.                                                                        | Writes a 90-line nested `if/else` block directly inside the `while` loop.                                                                        |
| **2** | **Prompt Context Quality**       | Specifies `/^\d+$/` strict integer check, injectable clock/random functions, and immediate abort when `> maxRetryAfter`.                                            | Prompts _"Add Retry-After support and exponential backoff"_.                                                                                     |
| **3** | **Not Blindly Trusting AI**      | Catches `parseInt("2026-10-21")` returning `2026` and catches `Math.min(delay, maxRetryAfter)` sleeping instead of aborting.                                        | Accepts `parseInt` and fails on ISO/RFC-850 dates starting with digits.                                                                          |
| **4** | **Code Reading Speed**           | Quickly sees how `Ky` clones `Request` objects and manages `Headers` instances.                                                                                     | Checks `request.headers['Idempotency-Key']` as a plain object instead of `request.headers.get('idempotency-key')`, failing on lowercase headers! |
| **5** | **Bug & Edge-Case Discovery**    | Tests `Retry-After: 0`, past HTTP-date (clock skew `-5s`), lowercase `idempotency-key: "   "` (whitespace-only key must be rejected!), and locked `ReadableStream`. | Misses case-sensitivity of `Idempotency-Key` or accepts an empty `Idempotency-Key: ""`.                                                          |
| **6** | **Testing Before Claiming Done** | Uses injectable `now` and `randomFn` to test backoff math deterministically in `< 50ms` without real multi-second sleeps.                                           | Writes tests that call `setTimeout(..., 5000)` and slow down the test suite.                                                                     |
| **7** | **Explaining Correctness**       | Explains why Full Jitter (`random(0, min(cap, base * 2^attempt))`) prevents synchronized retry waves (thundering herds) better than Equal/No Jitter.                | Cannot explain why jitter is needed in distributed systems.                                                                                      |

### Interviewer Probing Questions (Final 10 Minutes)

1. **Q**: _"Why does `parseInt(header, 10)` produce a subtle bug when parsing `Retry-After` headers?"_  
   **Expected Answer**: `parseInt` parses leading digits and ignores trailing non-digit characters. If a server sends an ISO timestamp `"2026-10-24T00:00:00Z"` or `"24 Oct 2026..."`, `parseInt` returns `2026` or `24` seconds instead of parsing it as a date!
2. **Q**: _"Why shouldn't an HTTP client automatically retry a failed `POST /payments` request unless an `Idempotency-Key` header is present?"_  
   **Expected Answer**: A `502`/`504` gateway timeout or dropped TCP connection occurs _after_ the request may have already reached the upstream server and charged the customer. Retrying without an `Idempotency-Key` risks charging the customer twice.
