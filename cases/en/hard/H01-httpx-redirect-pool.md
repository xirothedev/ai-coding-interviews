# H01 — Async HTTP Connection Pool & Cross-Origin Redirect Auth Leak

[⬅️ Back to Hard Catalog](README.md) · [🏠 Master Hub](../../../README.md)

| Attribute                    | Details                                                                                                                         |
| :--------------------------- | :------------------------------------------------------------------------------------------------------------------------------ |
| **Case ID**                  | `H01`                                                                                                                           |
| **Difficulty Level**         | 🔴 **Hard** (`60–75 mins` — Senior / Staff Bar)                                                                                 |
| **Task Archetype**           | Bugfix + Concurrency + Security Invariant                                                                                       |
| **Source GitHub Repository** | [`encode/httpx`](https://github.com/encode/httpx)                                                                               |
| **Target Files**             | `httpx/_client.py`, `httpx/_urls.py`, `httpx/_models.py`, `tests/client/test_redirects.py`, `tests/client/test_async_client.py` |
| **Supported Languages**      | `Python` _(Adaptable to Go `net/http` or TypeScript `undici`)_                                                                  |
| **Hard Taxonomy Pillars**    | Pillar 1 (Deceptive Abstraction) · Pillar 3 (Cross-Module Invariants) · Pillar 4 (Async Concurrency)                            |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Source Repository & Pull Request (Confidential)

| Field                              | Value                                      |
| :--------------------------------- | :----------------------------------------- |
| **Repository**                     | `https://github.com/encode/httpx`          |
| **Base SHA (pre-merge)**           | `4f8068a7ade1f4d10403e325ed2354109df1724f` |
| **Merge SHA (reference solution)** | `4401d55ecf0d95be237098b6c73c45420d54d499` |
| **Test Command**                   | `pytest`                                   |

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/encode/httpx.git interview-workspace
cd interview-workspace
git checkout 4f8068a7ade1f4d10403e325ed2354109df1724f
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
pytest
```

### Reproducibility Verification

- **Base SHA (`4f8068a7ade1`)**: the test suite must contain at least one failing test related to the issue.
- **Merge SHA (`4401d55ecf0d`)**: the same tests must pass after checkout.

### Files Changed (Reference Solution)

- httpx/_client.py, httpx/_utils.py

### Failing Tests to Enable

- Failing tests to enable/verify: test_redirects.py, test_utils.py. Run the test command to confirm red on Base SHA and green on Merge SHA.

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Bug Report: HTTP Client Redirect & Connection Pool Handling
>
> Our HTTP client mishandles redirects and connection pooling under certain conditions.
>
> ### Requirements
>
> - Preserve appropriate headers (such as Authorization) across HTTPS redirects.
> - Manage connection pool lifecycle correctly without leaks.
> - Handle redirect limits and method changes per spec.
>
> ### Acceptance Criteria
>
> 1. Trace the client and transport code.
> 2. Fix redirect header handling and pool management.
> 3. Verify with redirect and connection reuse scenarios.

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Trusting the first plausible fix

- **What Naive AI Writes**: A minimal edit that makes the happy path pass but ignores the edge cases exercised by the real PR (`Preserve Authorization header on HTTPS redirect`).
- **Why It Fails**: The PR touches `httpx/_client.py, httpx/_utils.py`; a shallow change leaves the underlying defect (ordering, caching, type resolution, or retry semantics) in place, so hidden tests still fail.
- **Correct Fix**: Reproduce the failing tests on Base SHA, then implement the same behavior change as the merged PR (study its diff), including edge cases and invariants.

### Trap 2: Over-editing unrelated code

- **What Naive AI Writes**: Refactors surrounding modules "while at it", changing public APIs.
- **Why It Fails**: Breaks callers and the hidden regression tests; the reference solution is minimal and scoped to the PR's changed lines.
- **Correct Fix**: Limit edits to the files/lines indicated by the failing tests; keep diffs small and behavior-focused.

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Trace the current behavior in `httpx/_client.py, httpx/_utils.py, test_redirects.py, test_utils.py` and identify why the failing tests fail on Base SHA."_
2. **Step 2 (`Plan`)**:
   - Reproduce with the test command; list the minimal files to change.
3. **Step 3 (`Prompt`)**:
   - Prompt 1: Implement the fix matching the merged PR's behavior, scoped to the failing tests.
   - Prompt 2: Add/adjust tests for edge cases (empty input, boundary values, error paths).
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Run the full test command; confirm all previously-failing tests pass and no regressions.

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

|   #   | Criterion                        | Strong Hire / Hire (`Score 3–4`)                                                                                                     | No Hire / Blind Vibe-Coder (`Score 1–2`)                                                           |
| :---: | :------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------- |
| **1** | **Problem Decomposition**        | Separates the 3 sub-problems (Origin/Headers, Async Cancellation, Cycle Detection) and solves/tests them one by one.                 | Pastes all 4 tasks into one giant prompt, producing a tangled 120-line diff across `_client.py`.   |
| **2** | **Prompt Context Quality**       | Explicitly mentions `BaseException` / `CancelledError`, `response.history` immutability, and `Set-Cookie` state in prompts.          | Prompts _"Fix redirect bugs and add loop detection in `_client.py`"_ with no constraints.          |
| **3** | **Not Blindly Trusting AI**      | Rejects AI's `visited_urls = set()` and `except Exception:` snippets before or immediately upon reviewing the diff.                  | Accepts `visited_urls = set()` blindly and gets confused when `test_post_303_to_same_url` fails.   |
| **4** | **Code Reading Speed**           | Quickly locates `BaseClient._build_redirect_request` and verifies how `URL.port` already normalizes default ports in `_urls.py`.     | Assumes `URL.port` is `None` without reading `_urls.py` or re-implements URL parsing from scratch. |
| **5** | **Bug & Edge-Case Discovery**    | Proactively spots `POST -> 303 GET /same-path`, `http:80 -> https:443` upgrade, and `Set-Cookie` state transitions.                  | Misses header mutation in `response.history` and only tests simple 2-node `A -> B -> A` loops.     |
| **6** | **Testing Before Claiming Done** | Uncomments all tests, runs `pytest` after each micro-change, and adds an async cancellation pool-exhaustion test.                    | Only runs synchronous tests and claims done without running `test_async_client.py`.                |
| **7** | **Explaining Correctness**       | Clearly explains why `CancelledError` is a `BaseException` in Python and why `(method, url, cookie_epoch)` prevents false positives. | Cannot explain why `http -> https` keeps `Authorization` while `https -> http` strips it.          |

### Interviewer Probing Questions (Final 10 Minutes)

1. **Q**: _"Why did we need `except BaseException:` instead of `except Exception:` in `AsyncClient._send_handling_redirects`?"_  
   **Expected Answer**: Since Python 3.8 (PEP 492 / bpo-32528), `asyncio.CancelledError` inherits from `BaseException` so broad `except Exception:` blocks don't accidentally swallow task cancellations. Catching `BaseException` to run `await response.aclose()` and re-raising ensures the socket returns to the pool.
2. **Q**: _"What happens if a server responds with `Set-Cookie` during a redirect back to the original URL?"_  
   **Expected Answer**: That is a state-changing redirect (common in OAuth/SSO flows), not an infinite loop. Tracking cookie mutations resets/advances the state epoch so the second visit is allowed.
