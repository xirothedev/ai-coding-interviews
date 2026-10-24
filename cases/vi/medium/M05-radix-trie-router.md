# M05 — Radix Trie URL Router & Wildcard Param Precedence

[⬅️ Back to Medium Catalog](README.md) · [🏠 Master Hub](../../../README.md)

| Attribute                    | Details                                                                                                                                 |
| :--------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------- |
| **Case ID**                  | `M05`                                                                                                                                   |
| **Difficulty Level**         | 🟡 **Medium** (`45–60 mins` — Standard SWE Bar)                                                                                         |
| **Task Archetype**           | Bugfix + Scale Optimization                                                                                                             |
| **Source GitHub Repository** | [`honojs/hono`](https://github.com/honojs/hono) (`src/router/trie-router`) · [`go-chi/chi`](https://github.com/go-chi/chi) (`tree.go`)  |
| **Target Files**             | `src/router/trie-router/node.ts`, `src/router/trie-router/router.ts`, `src/router/trie-router/router.test.ts` _(or `tree.go` in `chi`)_ |
| **Supported Languages**      | `TypeScript`, `Go`, `Python`, `Rust`                                                                                                    |
| **Primary AI Traps**         | Greedy static match failing to backtrack to `:param` · Shared mutable `params` map polluted by failed branch                            |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Source Repository & Pull Request (Confidential)

| Field                              | Value                                      |
| :--------------------------------- | :----------------------------------------- |
| **Repository**                     | `https://github.com/honojs/hono`           |
| **Base SHA (pre-merge)**           | `52febbcc30bc509d5e4987577e63906fe08fc471` |
| **Merge SHA (reference solution)** | `08807ce12aa3aa27c8c5adf63e677bbab6bceda9` |
| **Test Command**                   | `npm test`                                 |

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/honojs/hono.git interview-workspace
cd interview-workspace
git checkout 52febbcc30bc509d5e4987577e63906fe08fc471
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
npm test
```

### Reproducibility Verification

- **Base SHA (`52febbcc30bc`)**: the test suite must contain at least one failing test related to the issue.
- **Merge SHA (`08807ce12aa3`)**: the same tests must pass after checkout.

### Files Changed (Reference Solution)

- src/router/trie-router/node.ts

### Failing Tests to Enable

- Failing tests to enable/verify: node.test.ts, common.case.test.ts, router.test.ts. Run the test command to confirm red on Base SHA and green on Merge SHA.

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
>
> You are working on our Radix/Trie URL Router. You have full access to the AI Assistant and the test runner.
>
> ### What We Need You to Do
>
> Our HTTP framework routes incoming paths (`GET /orgs/acme/repos/core/issues`) against registered patterns containing **static segments**, **named parameters (`:name`, `:id{[0-9]+}`)**, **optional parameters (`:version?`)**, and **wildcards (`*` or `*filepath`)**.
>
> Users have reported three routing defects:
>
> 1. **Dead-End Prefix Backtracking Bug**:
>    - Suppose these routes are registered:
>      - `GET /users/admin/audit-log`
>      - `GET /users/:username/followers`
>      - `GET /users/*`
>    - When a request arrives for `GET /users/admin/followers`, the router enters the static `"admin"` branch, sees no `"followers"` child, and returns `404 Not Found`—failing to backtrack and match `:username = "admin"`.
> 2. **Parameter State Pollution During Backtracking**:
>    - Suppose these routes are registered:
>      - `GET /v1/:orgId/billing/invoices`
>      - `GET /v1/:tenantId/*`
>    - When `GET /v1/acme/billing/summary` is requested, Branch 1 captures `orgId = "acme"` and then fails on `"summary"`. Branch 2 matches `tenantId = "acme"`, but the returned `params` object contains `{ orgId: "acme", tenantId: "acme" }` (leaking `orgId` from the failed branch).
> 3. **Strict Specificity Precedence Regardless of Registration Order**:
>    - Whether routes are registered in order `[Wildcard, Param, Static]` or `[Static, Param, Wildcard]`, matching must follow deterministic specificity:
>      `Static segment > Regex-constrained :param{[0-9]+} > Standard :param > Wildcard *`
>
> Please explore the trie router codebase, re-enable any commented-out tests in the router test suite, fix the backtracking, parameter isolation, and specificity precedence bugs, and verify edge cases (including URL-encoded segments, trailing slashes, and multi-segment wildcards).

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Trusting the first plausible fix

- **What Naive AI Writes**: A minimal edit that makes the happy path pass but ignores the edge cases exercised by the real PR (`keep first value for duplicate path params`).
- **Why It Fails**: The PR touches `src/router/trie-router/node.ts`; a shallow change leaves the underlying defect (ordering, caching, type resolution, or retry semantics) in place, so hidden tests still fail.
- **Correct Fix**: Reproduce the failing tests on Base SHA, then implement the same behavior change as the merged PR (study its diff), including edge cases and invariants.

### Trap 2: Over-editing unrelated code

- **What Naive AI Writes**: Refactors surrounding modules "while at it", changing public APIs.
- **Why It Fails**: Breaks callers and the hidden regression tests; the reference solution is minimal and scoped to the PR's changed lines.
- **Correct Fix**: Limit edits to the files/lines indicated by the failing tests; keep diffs small and behavior-focused.

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Trace the current behavior in `src/router/trie-router/node.ts, node.test.ts, common.case.test.ts, router.test.ts` and identify why the failing tests fail on Base SHA."_
2. **Step 2 (`Plan`)**:
   - Reproduce with the test command; list the minimal files to change.
3. **Step 3 (`Prompt`)**:
   - Prompt 1: Implement the fix matching the merged PR's behavior, scoped to the failing tests.
   - Prompt 2: Add/adjust tests for edge cases (empty input, boundary values, error paths).
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Run the full test command; confirm all previously-failing tests pass and no regressions.

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

|   #   | Criterion                        | Strong Hire / Hire (`Score 3–4`)                                                                                                                                                       | No Hire / Blind Vibe-Coder (`Score 1–2`)                                                                 |
| :---: | :------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------- |
| **1** | **Problem Decomposition**        | Separates trie insertion structure from backtracking search and parameter map isolation.                                                                                               | Rewrites the entire router using an $O(N)$ linear array of RegExps, defeating the Trie!                  |
| **2** | **Prompt Context Quality**       | Explicitly specifies priority (`Static > Regex Param > Param > Wildcard`) and immutable/scoped `params` per branch.                                                                    | Prompts _"Fix the failing router test"_ without mentioning `params` state rollback.                      |
| **3** | **Not Blindly Trusting AI**      | Audits how `params` is passed across candidate branches and rejects linear-scan regex hacks.                                                                                           | Accepts AI code that mutates a single shared `params` object across failed branches.                     |
| **4** | **Code Reading Speed**           | Understands how `hono`'s `Node` stores `#children`, `#patterns`, `#params`, and `methods` within 8 minutes.                                                                            | Confuses route registration (`insert`) with route lookup (`search`).                                     |
| **5** | **Bug & Edge-Case Discovery**    | Tests deep backtracking (`/a/b/c/d` failing at `d` and falling back to `/:x/:y/:z/w`), mid-path `*`, and registration order permutations.                                              | Only tests 2-segment routes and misses multi-level backtracking.                                         |
| **6** | **Testing Before Claiming Done** | Runs the full `trie-router` test suite and adds a registration-order permutation test.                                                                                                 | Only tests `[Static, Param]` registration order and misses `[Param, Static]`.                            |
| **7** | **Explaining Correctness**       | Explains Trie time complexity ($O(L)$ where $L$ is path depth, worst-case bounded by overlapping parametric branches) and why DFS priority guarantees registration-order independence. | Cannot explain why a greedy trie fails on `/users/admin/followers` when `/users/admin/audit-log` exists. |

### Interviewer Probing Questions (Final 10 Minutes)

1. **Q**: _"Why can't a URL router with `:param` and `*` wildcards be a purely deterministic state machine without backtracking (unless compiled into a DFA)?"_  
   **Expected Answer**: Because at segment `"admin"` in `/users/admin/followers`, the router cannot know whether `"admin"` is the static route `/users/admin/audit-log` or the parameter `:username = "admin"` in `/users/:username/followers` until it inspects the _next_ segment (`"followers"`).

2. **Q**: _"Why must `params` be snapshotted or rolled back on backtrack?"_
   **Expected Answer**: Otherwise a parameter captured in a failed branch leaks into the successful branch.
