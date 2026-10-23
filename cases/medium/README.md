# 🟡 Medium Tier — Catalog & Routing Index (`10 Cases`, `45–60 Mins`)

[🏠 Back to Master Hub](../../README.md) · [🟢 Easy Tier](../easy/README.md) · [🔴 Hard Tier](../hard/README.md)

> **Standard AI-Enabled SWE Calibration (`L4–L5`, Meta / Canva / Stripe Bar):**  
> Each case below has its own **standalone page** containing:
> 1. **Interviewer Setup & Seeded Bug Manifest**
> 2. **Copy-Paste Candidate Prompt** (ready for CoderPad / Cursor / Codespaces)
> 3. **The AI Traps & Expected Solution**
> 4. **Reference Divide-and-Conquer Prompt Walkthrough (`Understand → Plan → Prompt → Review → Test`)**
> 5. **Case-Specific 7-Criteria HR Grading Rubric & Interviewer Probing Q&A**

---

## Master Routing Table — Medium Cases (`M01` – `M10`)

| Case ID | Standalone Case Page | Source GitHub Repository | Languages | Archetype | Primary AI Traps Tested |
| :-: | :--- | :--- | :--- | :--- | :--- |
| **`M01`** | **[Secret Word Puzzle & Entropy Solver Engine *(Meta Flagship)*](M01-wordle-puzzle-solver.md)** | [`agermanidis/wordle-solver`](https://github.com/agermanidis/wordle-solver) | `Python`, `TS`, `Go`, `Java` | Bugfix + Solver + Scale | Duplicate-letter 2-pass `Match.MOVE` bug · Variable word lengths (`1..6`) · $O(N^2)$ timeout on prod dictionary |
| **`M02`** | **[Legacy Service Refactoring & Dependency Inversion](M02-legacy-service-refactoring.md)** | [`JLLeitschuh/refactoring-interview-question`](https://github.com/JLLeitschuh/refactoring-interview-question) | `Java`, `TS`, `Python` | Legacy Refactor + Feature | Breaking public constructor signatures · Non-atomic `failFast=true` partial batch commits |
| **`M03`** | **[Concurrent Worker Pool & Graceful Context Cancellation](M03-concurrent-worker-pool.md)** | [`RezaSi/go-interview-practice`](https://github.com/RezaSi/go-interview-practice) | `Go`, `TS`, `Python`, `Rust` | System Integration + Concurrency | Returning before `wg.Wait()` (leaking goroutines) · Shared slice `append` data race vs indexed slot write |
| **`M04`** | **[HTTP Retry Middleware & Exponential Backoff Jitter](M04-http-retry-middleware.md)** | [`sindresorhus/ky`](https://github.com/sindresorhus/ky) / [`encode/httpx`](https://github.com/encode/httpx) | `TS`, `Python`, `Go` | Bugfix + Feature Extension | `parseInt` on HTTP-date `Retry-After` · Retrying `POST` without `Idempotency-Key` · Sleeping before throwing on `> maxRetryAfter` |
| **`M05`** | **[Radix Trie URL Router & Wildcard Param Precedence](M05-radix-trie-router.md)** | [`honojs/hono`](https://github.com/honojs/hono) / [`go-chi/chi`](https://github.com/go-chi/chi) | `TS`, `Go`, `Python`, `Rust` | Bugfix + Scale Optimization | Greedy static branch failing to backtrack to `:param` · Polluted shared `params` dictionary across branches |
| **`M06`** | **[Conduit Article Feed Pagination & N+1 Tag Hydration](M06-conduit-feed-pagination.md)** | [`gothinkster/realworld`](https://github.com/gothinkster/realworld) | `Python`, `TS`, `Go`, `Java` | Legacy Refactor + Scale | `LIMIT` applied to `LEFT JOIN` tag rows · Stripping sibling tags on `?tag=X` · Single-column timestamp cursor skipping ties |
| **`M07`** | **[Markdown Table & Footnote AST Tokenizer](M07-markdown-table-tokenizer.md)** | [`executablebooks/markdown-it-py`](https://github.com/executablebooks/markdown-it-py) | `Python`, `TS`, `Rust` | Bugfix + Feature Extension | Regex `(?<!\\)\|` failing on `\\\|` and inline code spans `` `a \| b` `` · Unclosed backtick row swallow |
| **`M08`** | **[In-Memory TTL Cache with LRU Eviction & Stampede Lock](M08-ttl-lru-cache-stampede.md)** | [`patrickmn/go-cache`](https://github.com/patrickmn/go-cache) / [`isaacs/node-lru-cache`](https://github.com/isaacs/node-lru-cache) | `Go`, `TS`, `Python`, `Java` | System Integration + Concurrency | Holding global cache mutex during slow `loaderFn` I/O · Caching rejected promises permanently |
| **`M09`** | **[CLI Subcommand Option Parser & Env-Var Precedence](M09-cli-option-precedence.md)** | [`pallets/click`](https://github.com/pallets/click) / [`tj/commander.js`](https://github.com/tj/commander.js) | `Python`, `TS`, `Go`, `Rust` | Bugfix + Feature Extension | Falsy CLI values (`False`, `0`, `""`) falling through `cli or env or default` · `"".split(",")` returning `[""]` |
| **`M10`** | **[Event-Sourced Ledger & Out-of-Order Webhook Reconciliation](M10-event-sourced-ledger.md)** | [`WiliamPerezBeltran/real_technical_tests`](https://github.com/WiliamPerezBeltran/real_technical_tests) | `TS`, `Python`, `Java`, `Go` | AI-Slop Rescue + State Machine | Out-of-order `CAPTURE(65)` before `AUTH_HOLD(100)` · Partial capture failing to release remainder of hold |
