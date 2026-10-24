# M05 — Radix Trie URL Router & Wildcard Param Precedence

[⬅️ Back to Medium Catalog](README.md) · [🏠 Master Hub](../../README.md)

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

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/honojs/hono.git hono-router-interview
cd hono-router-interview
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
npx vitest run src/router/trie-router
```

### Seeded Defects to Inject Before the Session

1. **Bug 1 (No Backtracking from Failed Static Prefix in `node.ts` / `tree.go`)**: In `Node.search()` (`src/router/trie-router/node.ts`, which traverses `#children`, `#patterns`, and `#params`), seed a greedy return `if (staticChild) { return search(staticChild, ...); }` without falling back to `#patterns` (`:param` / `*` wildcard) when `staticChild`'s subtree fails to match the remaining URL segments!
   - Example: Routes registered are `GET /users/profile/settings` and `GET /users/:id/posts`. Requesting `GET /users/profile/posts` enters static child `"profile"`, fails to find `"posts"`, and returns `404` instead of backtracking to `:id = "profile"`!
2. **Bug 2 (Polluted `#params` / `params` Dictionary Across Backtracked Branches)**: Mutate a shared `params: Record<string, string>` object across candidate branches in `node.ts` so that a parameter captured in a higher-priority branch that fails at a deeper segment remains inside `params` when a fallback branch succeeds!

---

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
>
> You are working on the Radix/Trie URL Router (`src/router/trie-router`). You have full access to the AI Assistant and test runner.
>
> ### Problem Context
>
> Our HTTP framework routes incoming paths (`GET /orgs/acme/repos/core/issues`) against registered patterns containing **static segments**, **named parameters (`:name`, `:id{[0-9]+}`)**, **optional parameters (`:version?`)**, and **wildcards (`*` or `*filepath`)**.
>
> Users have reported three routing defects:
>
> 1. **Dead-End Prefix Backtracking Bug**:
>    - Registered routes:
>      - `GET /users/admin/audit-log`
>      - `GET /users/:username/followers`
>      - `GET /users/*`
>    - When a request arrives for `GET /users/admin/followers`, the router enters the static `"admin"` branch, sees no `"followers"` child, and returns `404 Not Found`—failing to backtrack and match `:username = "admin"`!
> 2. **Parameter State Pollution During Backtracking**:
>    - Registered routes:
>      - `GET /v1/:orgId/billing/invoices`
>      - `GET /v1/:tenantId/*`
>    - When `GET /v1/acme/billing/summary` is requested, Branch 1 captures `orgId = "acme"`, then fails on `"summary"`. Branch 2 matches `tenantId = "acme"`, but the returned `params` object contains `{ orgId: "acme", tenantId: "acme" }` (leaking `orgId` from the failed branch!).
> 3. **Strict Precedence Regardless of Registration Order**:
>    - Whether routes are registered in order `[Wildcard, Param, Static]` or `[Static, Param, Wildcard]`, matching MUST follow deterministic specificity:
>      `Static segment > Regex-constrained :param{[0-9]+} > Standard :param > Wildcard *`
>
> ### Your Tasks
>
> 1. **Explore & Trace**: Read `node.ts` (`#children`, `#patterns`, `#params`) and `router.ts` in `src/router/trie-router/` (or `tree.go` in `go-chi/chi`).
> 2. **Run & Uncomment Tests**: Run `npx vitest run src/router/trie-router` and uncomment the backtracking, parameter isolation, and registration-order tests in `router.test.ts`.
> 3. **Fix Backtracking, Parameter Isolation & Specificity Precedence**: Implement clean fixes in `node.ts` / `router.ts`.
> 4. **Verify Edge Cases**: Test URL-encoded path segments (`/users/alice%20smith/posts`), trailing slashes, multi-segment wildcards (`/static/*filepath` capturing `"css/main.css"`), and registration-order permutation tests.

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Mutating `params[paramName] = part` Without Snapshot/Rollback on Backtrack

- **What Naive AI Writes**:
  ```ts
  // Inside recursive search(node, parts, index, params):
  if (node.paramChild) {
    params[node.paramChild.name] = parts[index];
    const match = search(node.paramChild, parts, index + 1, params);
    if (match) return match;
    // AI forgets to delete params[name] (or deletes a key that an ancestor already set!)
  }
  ```
- **Why It Fails**: If `params` is mutated in-place and not restored (or if `delete params[name]` deletes a parent param of the same name), failed branches corrupt the returned `params` map!
- **Correct Fix**: Either pass an immutable/copied `nextParams = { ...curParams, [name]: value }` down parameter edges (as `hono`'s `node.ts` does per candidate `curNode` in `nextCurNodes`) OR record `prevValue = params[name]; hadKey = name in params` and restore on backtrack!

### Trap 2: Wildcard `*` Consuming Only One Segment Instead of the Remainder of the Path

- **What Naive AI Writes**:
  - Treats `*` identically to `:param` (advancing `index + 1` instead of matching the rest of the path or checking terminal wildcard vs mid-path wildcard).
- **Correct Fix**: A terminal `*` (or `*filepath`) matches `parts.slice(index).join('/')`, whereas a mid-path wildcard `/prefix/*/suffix` must backtrack across remaining segment positions.

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Trace `insert()` and `search()` in `src/router/trie-router/node.ts`. Explain how `#children`, `#patterns`, and `#params` are stored and traversed."_
2. **Step 2 (`Plan`)**:
   - Candidate plans ordered candidate exploration (`Static > Regex Param > Plain Param > Wildcard`) with isolated `params` maps per candidate node.
3. **Step 3 (`Prompt`)**:
   - Prompt 1: Update `node.ts` traversal to backtrack across `Static -> Param -> Wildcard` in deterministic priority order while isolating captured `params`.
   - Prompt 2: Verify multi-segment wildcard capture and registration-order independence.
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Run `npx vitest run src/router/trie-router` and add a permutation test registering 5 overlapping routes in all `5! = 120` orders.

---

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
