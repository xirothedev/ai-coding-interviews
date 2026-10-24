# M06 — Conduit Article Feed Pagination & N+1 Tag Hydration

[⬅️ Back to Medium Catalog](README.md) · [🏠 Master Hub](../../../README.md)

| Attribute                    | Details                                                                                                                                                                                                                                                                                                                                         |
| :--------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Case ID**                  | `M06`                                                                                                                                                                                                                                                                                                                                           |
| **Difficulty Level**         | 🟡 **Medium** (`45–60 mins` — Standard SWE Bar)                                                                                                                                                                                                                                                                                                 |
| **Task Archetype**           | Legacy Refactoring & Performance Optimization                                                                                                                                                                                                                                                                                                   |
| **Source GitHub Repository** | [`nsidnev/fastapi-realworld-example-app`](https://github.com/nsidnev/fastapi-realworld-example-app) · [`gothinkster/node-express-realworld-example-app`](https://github.com/gothinkster/node-express-realworld-example-app) · [`gothinkster/golang-gin-realworld-example-app`](https://github.com/gothinkster/golang-gin-realworld-example-app) |
| **Target Files**             | `app/api/routes/articles/articles_resource.py`, `app/db/repositories/articles.py` _(or `src/app/routes/article/article.service.ts` in Express, `articles/models.go` in Go-Gin)_                                                                                                                                                                 |
| **Supported Languages**      | `Python`, `TypeScript`, `Go`, `Java`                                                                                                                                                                                                                                                                                                            |
| **Primary AI Traps**         | Returning `articles_count=len(articles)` instead of pre-limit total count · SQL `LIMIT` applied to `LEFT JOIN`ed tag rows · Single-column `created_at` cursor skipping tied rows                                                                                                                                                                |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Source Repository & Pull Request (Confidential)

| Field                              | Value                                                               |
| :--------------------------------- | :------------------------------------------------------------------ |
| **Repository**                     | `https://github.com/gothinkster/node-express-realworld-example-app` |
| **Base SHA (pre-merge)**           | `df9b999187d6edeeefc31f1981e46b9a7710148d`                          |
| **Merge SHA (reference solution)** | `17131d32f247c99bcb03de1c85189bc80284a97d`                          |
| **Test Command**                   | `npm test`                                                          |

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/gothinkster/node-express-realworld-example-app.git interview-workspace
cd interview-workspace
git checkout df9b999187d6edeeefc31f1981e46b9a7710148d
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
npm test
```

### Reproducibility Verification

- **Base SHA (`df9b999187d6`)**: the test suite must contain at least one failing test related to the issue.
- **Merge SHA (`17131d32f247`)**: the same tests must pass after checkout.

### Files Changed (Reference Solution)

- routes/api/articles.js

### Failing Tests to Enable

- Failing tests to enable/verify: the repository's existing tests covering this issue. Run the test command to confirm red on Base SHA and green on Merge SHA.

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
>
> You are working on the backend API of "Conduit" (the RealWorld blogging platform). You have full access to the AI Assistant and test suite.
>
> ### Problem Context
>
> The `GET /api/articles` endpoint is the highest-traffic route in our application, supporting filters (`?tag=`, `?author=`, `?favorited=`) and pagination (`?limit=20&offset=0`).
> Currently, three critical issues exist:
>
> 1. **Incorrect Filtered Page Size & Total Count**:
>    - Filtering by `?tag=dragons` when an article has multiple tags (e.g., `["dragons", "training", "magic"]`) must still return **all** tags of that article in `tagList: ["dragons", "magic", "training"]` (sorted alphabetically)—NOT just `["dragons"]`!
>    - Applying `?limit=10` must return exactly `10` distinct articles (when `>= 10` matching articles exist), and `articlesCount` must reflect the **total matching articles before `limit`/`offset`**, not `len(articles)`.
> 2. **N+1 Query Bottleneck**:
>    - Fetching `50` articles currently executes `1 + 5 * 50 = 251` database queries (fetching tags, author following status, and favorite count inside a loop).
>    - Optimize the data access layer so fetching `50` articles executes a **constant $O(1)$ number of queries (`<= 4` queries total)** regardless of `limit`.
> 3. **Keyset Cursor Pagination (`?cursor=`)**:
>    - Add optional cursor pagination (`?limit=20&cursor=<opaque_token>`) ordered by `created_at DESC, id DESC` so that even if 50 articles share the exact same `created_at` timestamp, paging through the feed never skips or duplicates a single article!
>
> ### Your Tasks
>
> 1. **Explore & Trace**: Trace `GET /api/articles` from route handler to database query and serializer.
> 2. **Run & Uncomment Tests**: Run the test suite and uncomment the query-count assertion, multi-tag filtering, and tied-timestamp cursor pagination tests.
> 3. **Fix Filtering, Eliminate N+1 Queries & Add Composite Cursor**: Implement all three improvements cleanly.
> 4. **Verify Edge Cases**: Test an article with `0` tags (`tagList: []`), filtering by `?tag=dragons` returning full `tagList`, and 30 articles with identical `created_at` paged with `limit=7`.

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Trusting the first plausible fix

- **What Naive AI Writes**: A minimal edit that makes the happy path pass but ignores the edge cases exercised by the real PR (`Fix for update article with tag list`).
- **Why It Fails**: The PR touches `routes/api/articles.js`; a shallow change leaves the underlying defect (ordering, caching, type resolution, or retry semantics) in place, so hidden tests still fail.
- **Correct Fix**: Reproduce the failing tests on Base SHA, then implement the same behavior change as the merged PR (study its diff), including edge cases and invariants.

### Trap 2: Over-editing unrelated code

- **What Naive AI Writes**: Refactors surrounding modules "while at it", changing public APIs.
- **Why It Fails**: Breaks callers and the hidden regression tests; the reference solution is minimal and scoped to the PR's changed lines.
- **Correct Fix**: Limit edits to the files/lines indicated by the failing tests; keep diffs small and behavior-focused.

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Trace the current behavior in `routes/api/articles.js` and identify why the failing tests fail on Base SHA."_
2. **Step 2 (`Plan`)**:
   - Reproduce with the test command; list the minimal files to change.
3. **Step 3 (`Prompt`)**:
   - Prompt 1: Implement the fix matching the merged PR's behavior, scoped to the failing tests.
   - Prompt 2: Add/adjust tests for edge cases (empty input, boundary values, error paths).
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Run the full test command; confirm all previously-failing tests pass and no regressions.

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

|   #   | Criterion                        | Strong Hire / Hire (`Score 3–4`)                                                                                                                  | No Hire / Blind Vibe-Coder (`Score 1–2`)                                                             |
| :---: | :------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------ | :--------------------------------------------------------------------------------------------------- |
| **1** | **Problem Decomposition**        | Separates article selection/counting from batch relation hydration (`WHERE article_id IN (...)`) and cursor encoding.                             | Tries to cram everything into a single giant SQL `JOIN` that breaks `LIMIT`.                         |
| **2** | **Prompt Context Quality**       | Explicitly specifies `WHERE EXISTS` for tag filtering, `IN (...)` batch loading, and composite `(created_at, id)` tie-breaking.                   | Prompts _"Fix N+1 and add cursor pagination"_, getting the broken `LEFT JOIN ... LIMIT` query.       |
| **3** | **Not Blindly Trusting AI**      | Spots both the `LEFT JOIN` + `LIMIT` row-multiplication bug and the missing sibling tags bug when filtering by `?tag=X`.                          | Accepts AI's `WHERE t.name = 'dragons'` join that wipes out all other tags on the returned articles! |
| **4** | **Code Reading Speed**           | Pinpoints the N+1 loop and in-memory pagination bug within 5–10 minutes.                                                                          | Wastes time editing response serializers instead of the repository query.                            |
| **5** | **Bug & Edge-Case Discovery**    | Tests articles with 0 tags, articles with 5 tags filtered by 1 tag, and 20 articles with identical `created_at` timestamps.                       | Only tests articles with distinct timestamps and 1 tag each.                                         |
| **6** | **Testing Before Claiming Done** | Asserts exact SQL query count (`<= 4`) and verifies zero missing/duplicate IDs across all cursor pages.                                           | Claims N+1 is fixed without asserting the number of executed SQL statements.                         |
| **7** | **Explaining Correctness**       | Explains why `LIMIT` on a 1-to-many join limits _joined rows_ rather than _root entities_, and why `(created_at, id)` forms a strict total order. | Cannot explain why `WHERE created_at <= :ts` causes duplicates while `< :ts` drops rows.             |

### Interviewer Probing Questions (Final 10 Minutes)

1. **Q**: _"What happens if you filter a `LEFT JOIN tags` query with `WHERE tags.name = 'dragons'` and also use that same join to populate `article.tagList`?"_  
   **Expected Answer**: The `WHERE` clause filters out all joined rows for the article's _other_ tags (like `'magic'`), so the API falsely returns `tagList: ['dragons']` instead of the article's full tag list! Using `WHERE EXISTS` (or fetching tags in a second batch query `WHERE article_id IN (...)`) preserves the full `tagList`.

2. **Q**: _"Why must pagination use a composite cursor instead of `created_at` alone?"_
   **Expected Answer**: Ties on the same timestamp cause duplicates or gaps across pages.
