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

- Re-enable any commented-out or skipped tests covering the issue; run `pytest` to confirm red on Base SHA and green on Merge SHA.

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Production Incident & Feature Ticket: HTTP Redirect Security, Pool Leaks & Loop Detection
>
> Security audit and production logs flagged three issues in our synchronous and asynchronous HTTP client around redirect handling (`301`, `302`, `303`, `307`, `308`):
>
> 1. **Cross-Origin & Scheme-Downgrade Credential Leak**:
>    - When following redirects, sensitive `Authorization` headers are being leaked across `https://` → `http://` scheme downgrades and non-standard port switches (`:443` → `:8443`). Conversely, valid `http://example.com:80` → `https://example.com:443` upgrades on the same host with default ports are mistakenly stripping `Authorization`.
>    - In addition, when a `POST` request receives a `303 See Other` redirect and switches to `GET`, removing body-related headers (`Content-Length`, `Transfer-Encoding`) mutates the original request's headers in-place inside `response.history[0].request.headers`, corrupting audit logs.
> 2. **Async Connection Pool Exhaustion on Task Cancellation**:
>    - In services running with a bounded connection pool (e.g., `max_connections=5`), cancelling an async request task while it is reading an intermediate redirect response body permanently leaks a connection slot, eventually hanging all subsequent requests.
> 3. **State-Aware Redirect Cycle Detection**:
>    - Right now, redirect loops always spin for the full `max_redirects=20` hops before failing with `TooManyRedirects`.
>    - We need deterministic cycle detection that aborts immediately with `TooManyRedirects` when a stateless redirect loop occurs, **without** breaking valid OAuth/SSO login flows where `GET /dashboard` → `302 /login` (which sets a session cookie via `Set-Cookie`) → `302 /dashboard` succeeds, or `POST /submit` → `303 /submit` (which transitions to `GET /submit`).
>
> ### Expected Behavioral Contracts
>
> - **Origin Equality & Safe HTTPS Upgrades**:
>   - `https://api.example.com/v1` and `https://api.example.com:443/v2` share the same origin (implicit default port `443` for `https`, `80` for `http`) and must retain `Authorization`.
>   - `https://api.example.com/v1` → `http://api.example.com/v2` is a scheme downgrade and **must strip** `Authorization`.
>   - `http://api.example.com/v1` → `https://api.example.com/v2` (or `:80` → `:443`) on the same host with default ports is a safe HTTPS upgrade and **must retain** `Authorization`, whereas switching to a non-default port (e.g., `http://api.example.com:8080` → `https://api.example.com:8443`) must strip `Authorization`.
>   - Request objects recorded in `response.history` must never have their headers mutated by subsequent redirect hops.
> - **Stateful vs. Stateless Redirect Loops**:
>   - `GET /a` → `302 /b` → `302 /a` (with no `Set-Cookie` state change and identical HTTP method) must raise `TooManyRedirects` immediately upon encountering the repeat of `('GET', 'https://.../a')`.
>   - `POST /submit` → `303 /submit` (`GET /submit`) and `GET /app` → `302 /auth` (`Set-Cookie: sid=123`) → `302 /app` are valid state transitions and must **not** raise `TooManyRedirects`.
>
> ### Acceptance Criteria
>
> 1. Locate the redirect, URL origin, and client request-handling logic in the codebase, and uncomment any disabled redirect security and cancellation tests in the test suite.
> 2. Fix origin comparison, preserve header immutability across `response.history`, and guarantee that cancelling an async request mid-redirect always closes and releases the underlying response connection back to the pool.
> 3. Implement state-aware redirect cycle detection for both sync and async clients, and add regression tests covering OAuth cookie redirects, `POST -> 303 GET` self-redirects, and async task cancellation under tight connection limits.

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Mutating `request.headers` In-Place

- **What Naive AI Writes**:
  ```python
  if method != request.method and method == "GET":
      request.headers.pop("Content-Length", None)
      request.headers.pop("Transfer-Encoding", None)
  ```
- **Why It Fails**: `request` is the previous hop's `Request` object stored in `response.history`. Mutating `request.headers` alters historical audit data!
- **Correct Fix**: Always clone `headers = Headers(request.headers)` first and mutate only the new copy passed to the next `Request`.

### Trap 2: Catching `Exception` Instead of `BaseException`

- **What Naive AI Writes**:
  ```python
  try:
      await response.aread()
  except Exception:
      await response.aclose()
      raise
  ```
- **Why It Fails**: In Python 3.8+, `asyncio.CancelledError` subclasses `BaseException`, not `Exception`. When an async request is cancelled via `task.cancel()`, `except Exception:` is bypassed completely and the underlying socket is never returned to the connection pool!
- **Correct Fix**: Use `except BaseException:` (or `try ... finally:` when closing intermediate redirect responses).

### Trap 3: Naive `visited_urls: set[URL]` Breaking Login & `303` Flows

- **What Naive AI Writes**:
  ```python
  if redirect_url in visited_urls:
      raise TooManyRedirects("Redirect loop detected", request=request)
  ```
- **Why It Fails**:
  1. `POST /items` returning `303 See Other` with `Location: /items` redirects to `GET /items` (same URL, different method!).
  2. `GET /me` → `302 /sso` (`Set-Cookie: token=xyz`) → `302 /me` visits `/me` twice, but the cookie jar state changed in between!
- **Correct Fix**: Key the visited set by `(request.method, canonical_url)` AND clear `visited` (or include a cookie-state epoch counter) whenever a redirect response contains a `Set-Cookie` header that updates `self._cookies`.

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code yet. Read `httpx/_client.py` and `httpx/_urls.py`. Trace `_send_handling_redirects` and `_build_redirect_request`. Explain: (1) how `URL.port` behaves when no explicit port is in the URL string, (2) where `request.headers` is copied vs mutated, and (3) what happens if `response.aread()` raises `asyncio.CancelledError`."_
2. **Step 2 (`Plan`)**:
   - Candidate identifies the 3 isolated changes in `httpx/_client.py`: `_redirect_headers` immutability + port-aware origin check, `BaseException` cleanup in `AsyncClient`, and `(method, url, cookie_epoch)` loop detection.
3. **Step 3 (`Prompt`)**:
   - Prompt each helper method individually (`_redirect_headers` first, then `_send_handling_redirects`), specifying exact invariants.
4. **Step 4 (`Review`)** & **Step 5 (`Test`)**:
   - Audit diff for `BaseException` and header cloning; run `pytest tests/client/test_redirects.py`.

---

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
