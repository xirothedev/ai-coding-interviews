# M06 — Conduit Article Feed Pagination & N+1 Tag Hydration

> 🌐 Ngôn ngữ: <a href="M06-conduit-feed-pagination">English</a> · **Tiếng Việt**

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

### Clean-Room Workspace Provisioning & Native Defects

```bash
git clone https://github.com/nsidnev/fastapi-realworld-example-app.git conduit-interview
cd conduit-interview
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
pytest
```

Notice that **`nsidnev/fastapi-realworld-example-app` natively exhibits both classic Conduit backend bugs** out of the box (no artificial bug seeding required!):

1. **Native Bug 1 (`articles_count=len(articles)` in `app/api/routes/articles/articles_resource.py` lines 69 & 98)**: Both `get_articles_feed` and `retrieve_articles` return `ListOfArticlesInResponse(articles=articles, articles_count=len(articles))`—reporting the **page slice length** (`<= limit`) instead of the total number of matching articles before `limit`/`offset`!
2. **Native Bug 2 (`1 + 5N` Query Comprehension in `app/db/repositories/articles.py` lines 257–264)**: `ArticlesRepository.filter_articles()` fetches the list of article rows and then runs an async list comprehension `[await self._get_article_from_db_record(...) for article_row in article_rows]`, where every single article fires **5 separate SQL queries** (`get_tags_for_article_by_slug`, `get_favorites_count_for_article_by_slug`, `is_article_favorited_by_user`, `get_profile_by_username`, `is_user_following_for_another`)—executing `1 + 5 * 20 = 101` SQL queries for a single 20-article page!
3. **Bug 3 (Unstable Timestamp Pagination)**: Sorting only by `ORDER BY created_at DESC` causes articles created in the same millisecond to duplicate or vanish across pages.

---

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

### Trap 1: Applying `LIMIT` to a 1-to-Many `LEFT JOIN` Query

- **What Naive AI Writes**:
  ```sql
  SELECT a.*, t.name AS tag_name
  FROM articles a
  LEFT JOIN article_tags at ON a.id = at.article_id
  LEFT JOIN tags t ON t.id = at.tag_id
  ORDER BY a.created_at DESC
  LIMIT 20 OFFSET 0; -- <-- BUG! 4 articles with 5 tags each = 20 rows = only 4 articles returned!
  ```
- **Also**: If a `WHERE t.name = 'dragons'` clause is put on the outer join, `t.name` only returns `'dragons'`, stripping all other tags (`'magic'`, `'training'`) from the response's `tagList`!
- **Correct Fix**:
  1. Query 1: Fetch the paginated article IDs/rows using `WHERE EXISTS (SELECT 1 FROM article_tags ... WHERE tag = :tag)` (or subquery) with `ORDER BY a.created_at DESC, a.id DESC LIMIT :limit`.
  2. Query 2: Batch-load all tags (`WHERE article_id IN (:article_ids)`) and favorites in bulk, grouping by `article_id` in memory! This takes exactly 2–3 queries total ($O(1)$ queries) and never truncates `LIMIT` or strips sibling tags!

### Trap 2: Single-Column Cursor (`WHERE created_at < :cursor_ts`)

- **What Naive AI Writes**:
  - Encodes only `created_at` in the cursor and filters `WHERE created_at < :cursor_ts`.
- **Why It Fails**: If 10 articles have `created_at = '2026-10-24T00:00:00Z'` and `limit = 5`, Page 1 returns the first 5 (`id` 10..6), and Page 2 (`WHERE created_at < '2026-10-24T00:00:00Z'`) **skips `id` 5..1 completely**!
- **Correct Fix**: Encode `(created_at, id)` in the cursor and filter:
  ```sql
  WHERE (a.created_at < :cursor_ts)
     OR (a.created_at = :cursor_ts AND a.id < :cursor_id)
  ORDER BY a.created_at DESC, a.id DESC
  ```

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Trace `GET /api/articles` and count how many SQL queries execute for `limit=20`. Show where `tag` filtering and `limit/offset` happen."_
2. **Step 2 (`Plan`)**:
   - Candidate plans the 2-query batch hydration strategy (`WHERE EXISTS` on `articles` with `LIMIT`, followed by `WHERE article_id IN (...)` for tags/favorites) and the composite `(created_at, id)` keyset predicate.
3. **Step 3 (`Prompt`)**:
   - Prompt 1: Fix filtered query + total count + batch tag hydration.
   - Prompt 2: Add composite `(created_at, id)` base64 cursor encoding/decoding and SQL predicate.
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Verify query counter asserts `<= 4` queries for `50` articles and run all pagination tests.

---

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
