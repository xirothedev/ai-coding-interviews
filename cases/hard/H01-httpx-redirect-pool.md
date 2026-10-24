# H01 — Async HTTP Connection Pool & Cross-Origin Redirect Auth Leak

[⬅️ Back to Hard Catalog](README.md) · [🏠 Master Hub](../../README.md)

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

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/encode/httpx.git httpx-interview
cd httpx-interview
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
```

### Seeded Defects to Inject (or Checkout) Before the Session

In `httpx/_client.py`:

1. **Bug 1 (Origin Port/Scheme Downgrade Leak)**: In module-level `_same_origin(url, other)` and `_is_https_redirect(request.url, url)` (and `BaseClient._redirect_headers()`) in `httpx/_client.py`, replace the port/scheme check so `url.host == other.host` is treated as same-origin without verifying `port` normalization or `https -> http` downgrade, and mutate `request.headers` in-place when removing `Content-Length` on `303 See Other`.
2. **Bug 2 (Async Cancellation Connection Leak)**: In `AsyncClient._send_handling_redirects()`, catch `except Exception:` instead of `except BaseException:` around `await response.aread()` before following a redirect (in Python 3.8+, `asyncio.CancelledError` inherits from `BaseException`, so cancelling a request mid-redirect skips `await response.aclose()` and leaks the connection slot!).
3. **Commented Tests**: Comment out `test_cross_domain_redirect_with_auth_header` and `test_https_to_http_downgrade_strips_auth` in `tests/client/test_redirects.py`, and add `test_async_redirect_cancellation_releases_connection` as a commented-out test during this interviewer seed step in `tests/client/test_redirects.py`.

---

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
>
> You are working inside a production-grade synchronous/asynchronous HTTP client (`httpx`). You may use the AI Assistant as much or as little as you like, but you are evaluated on how you navigate the codebase, decompose changes, verify AI output, and defend your solution.
>
> ### Problem Context
>
> Enterprise users have reported three critical issues with HTTP redirect handling (`301`, `302`, `303`, `307`, `308`):
>
> 1. **Security & Audit Defect**: When following redirects, sensitive `Authorization` headers are leaked during `https://` → `http://` downgrades or non-standard port switches (`:443` → `:8443`), while `http://example.com:80` → `https://example.com:443` upgrades mistakenly strip `Authorization`. Additionally, `POST` → `303 See Other` (`GET`) mutates the original request's headers inside `response.history[0].request.headers`.
> 2. **Async Pool Exhaustion**: Under `Limits(max_connections=5)`, cancelling an `AsyncClient` task while it is reading an intermediate redirect response permanently leaks a connection slot, eventually hanging all future requests.
> 3. **Stateful Redirect Cycle Detection**: Currently, redirect loops always run for `max_redirects=20` hops before raising `TooManyRedirects`. We need deterministic cycle detection that aborts immediately when a stateless redirect cycle occurs, **without** breaking valid OAuth/login flows where `GET /dashboard` → `302 /login` (sets a session cookie via `Set-Cookie`) → `302 /dashboard` succeeds!
>
> ### Specification & Examples
>
> - **Origin Equality (`_same_origin`)**:
>   - `https://api.example.com/v1` and `https://api.example.com:443/v2` → **Same Origin** (`port` defaults to `443` for `https`).
>   - `https://api.example.com/v1` → `http://api.example.com/v2` → **Downgrade** (MUST strip `Authorization`).
>   - `http://api.example.com/v1` → `https://api.example.com/v2` → **Safe HTTPS Upgrade on same host/default ports** (Keep `Authorization`).
> - **Stateful vs. Stateless Redirect Loop**:
>   - `GET /a` → `302 /b` → `302 /a` (no `Set-Cookie` header and method unchanged) → Raise `TooManyRedirects` immediately on the repeat of `('GET', 'https://.../a')`.
>   - `POST /submit` → `303 /submit` (`GET /submit`) OR `GET /app` → `302 /auth` (`Set-Cookie: sid=123`) → `302 /app` → **Valid** (must NOT raise `TooManyRedirects`).
>
> ### Your Tasks
>
> 1. **Explore & Trace**: Map module-level `_same_origin(url, other)` and `_is_https_redirect(url, location)`, along with `BaseClient`, `Client`, and `AsyncClient` redirect handling in `httpx/_client.py` and URL port normalization in `httpx/_urls.py`.
> 2. **Run & Uncomment Tests**: Run `pytest tests/client/test_redirects.py`. Uncomment the disabled redirect security and cancellation tests and observe the failures.
> 3. **Fix Redirect Headers & Async Pool Leak**: Fix origin comparison, preserve `response.history` request header immutability, and ensure `AsyncClient` releases connections on task cancellation.
> 4. **Implement Cycle Detection & Verify**: Implement state-aware redirect loop detection and write unit tests covering OAuth cookie redirects, `POST -> 303 GET` self-redirects, and task cancellation.

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
