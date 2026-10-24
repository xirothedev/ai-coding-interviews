# M08 — In-Memory TTL Cache with LRU Eviction & Stampede Lock

[⬅️ Back to Medium Catalog](README.md) · [🏠 Master Hub](../../README.md)

| Attribute                    | Details                                                                                                                                                                                 |
| :--------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Case ID**                  | `M08`                                                                                                                                                                                   |
| **Difficulty Level**         | 🟡 **Medium** (`45–60 mins` — Standard SWE Bar)                                                                                                                                         |
| **Task Archetype**           | System Component Integration & Concurrency                                                                                                                                              |
| **Source GitHub Repository** | [`hashicorp/golang-lru`](https://github.com/hashicorp/golang-lru) (`expirable/expirable_lru.go`) · [`isaacs/node-lru-cache`](https://github.com/isaacs/node-lru-cache) (`src/index.ts`) |
| **Target Files**             | `expirable/expirable_lru.go`, `expirable/expirable_lru_test.go`, `internal/list.go` _(or `src/index.ts` in `node-lru-cache`)_                                                           |
| **Supported Languages**      | `Go`, `TypeScript`, `Python`, `Java`                                                                                                                                                    |
| **Primary AI Traps**         | Evicting a valid LRU item when `Add()`/`Set()` is called while expired items occupy capacity · Holding global cache mutex during slow `loaderFn` I/O · Caching rejected promises        |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/hashicorp/golang-lru.git cache-interview
cd cache-interview
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
go test -race ./expirable/...
```

_(Or use [`isaacs/node-lru-cache`](https://github.com/isaacs/node-lru-cache) `src/index.ts` for TypeScript.)_

### Seeded Defects to Inject Before the Session

1. **Bug 1 (Expired Items Evicting Live LRU Keys in `expirable/expirable_lru.go`)**: Notice that in `hashicorp/golang-lru/expirable/expirable_lru.go`, when `Add(key, value)` is called at full capacity (`c.evictList.Length() > c.size`), it calls `c.removeOldest()` (which evicts the tail of the LRU list `c.evictList.Back()`) **without checking whether other entries in the cache have already expired by TTL (`time.Now().After(ent.expiresAt)`)**! If key `"B"` was recently read (`MoveToFront`) right before its short TTL expired, while key `"A"` has a longer TTL and sits at the LRU tail, inserting `"C"` evicts **live** key `"A"` while **expired** key `"B"` continues occupying a capacity slot!
2. **Bug 2 (Expired Read Promoting Item in LRU List)**: In `Get(key)`, seed or inspect the check so an expired entry is promoted via `c.evictList.MoveToFront(ent)` or left in `c.items` instead of calling `c.removeElement(ent)` immediately on expired read!

---

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
>
> You are working on an in-memory bounded **TTL + LRU Cache** module. You have full access to the AI Assistant and test runner.
>
> ### Problem Context
>
> Our high-throughput service relies on this cache to store database/API lookups with both a **per-entry TTL (`ttl`)** and a **maximum entry capacity (`maxCapacity`)**:
>
> 1. **Bug A — Expired Entries Causing False LRU Evictions**:
>    - If `maxCapacity = 3` and the cache contains `["A" (expired), "B" (live, LRU), "C" (live, MRU)]`, inserting `"D"` currently evicts live key `"B"` instead of reclaiming the slot from expired key `"A"`!
>    - Additionally, calling `Get("A")` on an expired key must lazily remove `"A"` from both the hash map and the doubly-linked list so `Size()` reflects only live items.
> 2. **Feature — `GetOrLoad(key, ttl, loaderFn)` with Cache Stampede (Singleflight) Protection**:
>    - When a popular key expires, 100 concurrent requests hit `GetOrLoad("homepage", ttl, loaderFn)` at the same millisecond.
>    - **Requirement 1 (Singleflight Coalescing)**: `loaderFn("homepage")` must execute **exactly once**, and all 100 concurrent callers must receive the loaded value (or error).
>    - **Requirement 2 (Non-Blocking Across Different Keys)**: While `loaderFn("slow-key")` is taking `200ms` to fetch from the database, concurrent calls to `Get("fast-key")`, `Set("other-key")`, or `GetOrLoad("other-key")` MUST NOT be blocked waiting for `"slow-key"`!
>    - **Requirement 3 (Failure Recovery)**: If `loaderFn("homepage")` returns an error (or throws/panics), do NOT cache the error; remove the in-flight entry immediately so a subsequent request can retry.
>
> ### Your Tasks
>
> 1. **Explore & Trace**: Inspect the hash map, doubly-linked LRU list, and TTL expiration checks.
> 2. **Run & Uncomment Tests**: Run the test suite and uncomment the TTL-vs-LRU eviction and `GetOrLoad` stampede tests.
> 3. **Fix TTL/LRU Eviction & Implement `GetOrLoad`**: Ensure $O(1)$ amortized operations and fine-grained concurrency.
> 4. **Verify Edge Cases**: Test `loaderFn` throwing/panicking, 50 concurrent callers on the same key vs. 50 distinct keys, and updating an existing key via `Set()`.

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Holding the Global Cache Mutex While `loaderFn(key)` Executes!

- **What Naive AI Writes**:
  ```go
  func (c *Cache) GetOrLoad(key string, ttl time.Duration, loader func() (any, error)) (any, error) {
      c.mu.Lock()
      defer c.mu.Unlock() // <-- CATASTROPHIC! Locks the entire cache during network I/O!
      if val, ok := c.getUnlocked(key); ok { return val, nil }
      val, err := loader()
      ...
  }
  ```
- **Why It Fails**: Holding `c.mu.Lock()` across `loader()` (which may take `200ms` of network I/O) blocks every `Get()` and `Set()` on completely unrelated keys across the entire application! Even worse, if `loader()` itself calls `c.Get("other-key")`, the goroutine **deadlocks on its own non-reentrant `sync.Mutex`**!
- **Correct Fix (Two-Phase Singleflight Pattern)**:
  1. Acquire `c.mu.Lock()` briefly:
     - Check if `key` is in cache and unexpired → return immediately.
     - Check if `call, ok := c.inflight[key]` exists → if so, `c.mu.Unlock()`, wait on `<-call.done`, and return `(call.val, call.err)`.
     - Otherwise, create `call := &inflightCall{done: make(chan struct{})}`, store `c.inflight[key] = call`, and **`c.mu.Unlock()` BEFORE calling `loader()`**!
  2. Execute `loader()` **outside** `c.mu.Lock()` (with `defer` cleanup that re-acquires `c.mu.Lock()`, stores result if `err == nil`, deletes `c.inflight[key]`, and closes `call.done` even if `loader()` panics!).

### Trap 2: In TypeScript/JS,Forgetting `.finally()` Cleanup on Rejected In-Flight Promises

- **What Naive AI Writes (TypeScript)**:
  ```ts
  const promise = loaderFn(key).then((val) => {
    this.set(key, val, ttl);
    this.inflight.delete(key);
    return val;
  });
  this.inflight.set(key, promise);
  return promise;
  ```
- **Why It Fails**: If `loaderFn(key)` rejects, the `.then()` callback never runs, so `this.inflight.delete(key)` is never called! Every future call to `getOrLoad(key)` forever returns the permanently cached rejected Promise!
- **Correct Fix**: Use `try { ... } finally { this.inflight.delete(key); }`.

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Trace how `Get`, `Set`, and LRU eviction currently interact with TTL expiration."_
2. **Step 2 (`Plan`)**:
   - Plan: (1) Fix lazy deletion on `Get` and purge expired items before evicting live LRU tail on `Set`; (2) Implement `GetOrLoad` with an `inflight` map where `loaderFn` runs outside the global lock and `defer`/`finally` guarantees `inflight` cleanup.
3. **Step 3 (`Prompt`)** & **Step 4 (`Review`)**:
   - Prompt each part separately; audit lock scope around `loaderFn` and panic/error cleanup.

---

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

|   #   | Criterion                        | Strong Hire / Hire (`Score 3–4`)                                                                                                      | No Hire / Blind Vibe-Coder (`Score 1–2`)                                                       |
| :---: | :------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------ | :--------------------------------------------------------------------------------------------- |
| **1** | **Problem Decomposition**        | Fixes TTL/LRU data structure invariants first, then layers singleflight `inflight` coordination on top.                               | Mixes linked-list node pointers with async/goroutine locking in one big prompt.                |
| **2** | **Prompt Context Quality**       | Explicitly specifies releasing the cache mutex _before_ invoking `loaderFn` and cleaning up `inflight[key]` in `defer`/`finally`.     | Prompts _"Add GetOrLoad with thread safety"_, getting the global lock-across-I/O anti-pattern. |
| **3** | **Not Blindly Trusting AI**      | Spots global lock contention during `loaderFn` and rejected-Promise / panic poisoning in diff review.                                 | Accepts `c.mu.Lock(); defer c.mu.Unlock()` around `loaderFn()`.                                |
| **4** | **Code Reading Speed**           | Quickly maps the hash map + doubly-linked list + expiration timestamp fields.                                                         | Breaks doubly-linked list `prev`/`next` pointers when deleting expired nodes.                  |
| **5** | **Bug & Edge-Case Discovery**    | Tests `loaderFn` panicking/throwing, `loaderFn` calling `cache.Get(otherKey)` re-entrantly, and expired items at capacity boundary.   | Never tests what happens after `loaderFn` fails once and is called a second time.              |
| **6** | **Testing Before Claiming Done** | Writes a concurrency test proving `loaderFn("k1")` sleeping `100ms` does not block `GetOrLoad("k2")` (`< 5ms`).                       | Only tests single-threaded calls to `GetOrLoad`.                                               |
| **7** | **Explaining Correctness**       | Explains the Singleflight (`golang.org/x/sync/singleflight`) pattern and why holding locks across I/O causes convoying and deadlocks. | Cannot explain what happens if `loaderFn` calls back into the cache while the lock is held.    |

### Interviewer Probing Questions (Final 10 Minutes)

1. **Q**: _"What happens if `loaderFn("user:1")` internally calls `cache.Get("config:timeout")`, and your `GetOrLoad` holds `c.mu.Lock()` while calling `loaderFn`?"_  
   **Expected Answer**: In Go (or Python `threading.Lock` / Rust `Mutex`), mutexes are non-reentrant. The goroutine will block forever trying to acquire `c.mu.Lock()` inside `cache.Get` while already holding it in `GetOrLoad`—an instant self-deadlock!
