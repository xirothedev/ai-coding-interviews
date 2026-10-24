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

- Re-enable any commented-out or skipped tests covering the issue; run `npm test` to confirm red on Base SHA and green on Merge SHA.

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
>
> You are working on the retry and backoff engine of our HTTP client. You have full access to the AI Assistant and the test runner.
>
> ### What We Need You to Do
>
> Production services using our HTTP retry logic hit three reliability issues during an upstream outage:
>
> 1. **`Retry-After` Header Parsing & Cap Enforcement (RFC 7231)**:
>    - Upstream servers return `Retry-After` on `429 Too Many Requests` and `503 Service Unavailable` in **two standard formats**:
>      - Delay-seconds: `"120"` (wait `120,000 ms`)
>      - HTTP-date: `"Wed, 21 Oct 2026 07:28:00 GMT"` (wait `Date.parse(header) - now`)
>    - **Requirements**:
>      - Parse both formats accurately.
>      - If the HTTP-date is in the past (due to clock skew), clamp the delay to `0 ms` (never negative).
>      - If the computed `Retry-After` delay exceeds `retryOptions.maxRetryAfter` (e.g., `10_000 ms`), **abort immediately and rethrow the error without sleeping**.
> 2. **Idempotency-Aware Retry Guard**:
>    - Safe/idempotent methods (`GET`, `HEAD`, `OPTIONS`, `PUT`, `DELETE`) may retry on configured retryable status codes (`408`, `429`, `500`, `502`, `503`, `504`).
>    - `POST` and `PATCH` requests must **only** be retried if the request headers contain a non-empty `Idempotency-Key` (case-insensitive header lookup).
> 3. **Full-Jitter Exponential Backoff & Unreplayable Stream Body Guard**:
>    - When `Retry-After` is absent, compute backoff delay using **Full Jitter**: `random(0, min(capMs, baseMs * 2 ** (attempt - 1)))` using an injectable `randomFn` (defaulting to `Math.random`) for deterministic testing.
>    - If a request has a non-replayable body (a consumed `ReadableStream` where `body.locked` or `bodyUsed` is true and cannot be cloned), do **not** retry.
>
> Please explore the codebase, re-enable any commented-out retry tests in the test suite, implement all three requirements, and verify edge cases (including past HTTP-dates, `Retry-After > maxRetryAfter` fast-fail without sleeping, case-insensitive `idempotency-key`, and stream bodies).

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Using `parseInt(retryAfter, 10)` Before Checking Date Format

- **What Naive AI Writes**:
  ```ts
  const seconds = parseInt(retryAfterHeader, 10);
  if (!Number.isNaN(seconds)) return seconds * 1000;
  ```
- **Why It Fails**: What if a non-standard date string starts with a digit (e.g., `"21 Oct 2026 07:28:00 GMT"` or ISO `"2026-10-21T..."`)? `parseInt("2026-10-21...", 10)` stops at the hyphen and returns `2026` seconds (`33 minutes`)!
- **Correct Fix**: Test `/^\d+$/.test(retryAfterHeader.trim())` for integer delay-seconds; otherwise parse with `Date.parse(retryAfterHeader)` and clamp `Math.max(0, parsedDate - now)`.

### Trap 2: Sleeping for `maxRetryAfter` Before Throwing When `Retry-After > maxRetryAfter`

- **What Naive AI Writes**:
  ```ts
  const delay = Math.min(parsedRetryAfter, options.maxRetryAfter);
  await sleep(delay);
  ```
- **Why It Fails**: If a rate-limited server says `Retry-After: 3600` (1 hour) and `maxRetryAfter` is `10s`, sleeping `10s` and retrying against a 1-hour ban wastes `10s` and hammers a banned endpoint! The spec requires **aborting immediately without sleeping** when `parsedRetryAfter > options.maxRetryAfter`.

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Trace how retry eligibility and delay calculation currently work in `source/core/Ky.ts`, `source/core/retry-timing.ts`, `test/retry.ts`, `test/retry-timing.ts`, and `test/retry-decisions.ts`."_
2. **Step 2 (`Plan`)**:
   - Extract a pure, unit-testable `calculateRetryDelay({ attempt, retryAfterHeader, options, now, randomFn })` function and a pure `canRetryRequest(request, response, options)` predicate.
3. **Step 3 (`Prompt`)**:
   - Prompt 1: Implement `calculateRetryDelay` handling `/^\d+$/`, HTTP-dates, `Math.max(0, ...)`, and `maxRetryAfter` threshold.
   - Prompt 2: Implement `canRetryRequest` checking HTTP method, `Headers.has('idempotency-key')`, and stream body replayability.
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Audit regex `/^\d+$/` vs `parseInt`, and run `npm test`.

---

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
