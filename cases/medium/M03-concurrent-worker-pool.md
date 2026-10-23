# M03 — Concurrent Worker Pool & Graceful Context Cancellation

[⬅️ Back to Medium Catalog](README.md) · [🏠 Master Hub](../../README.md)

| Attribute | Details |
| :--- | :--- |
| **Case ID** | `M03` |
| **Difficulty Level** | 🟡 **Medium** (`45–60 mins` — Standard SWE Bar) |
| **Task Archetype** | System Component Integration & Concurrency |
| **Source GitHub Repository** | [`RezaSi/go-interview-practice`](https://github.com/RezaSi/go-interview-practice) |
| **Target Files** | Worker pool / concurrency challenge package & `*_test.go` |
| **Supported Languages** | `Go` *(Primary)*, `TypeScript`, `Python` (`asyncio`), `Rust` (`tokio`) |
| **Primary AI Traps** | Goroutine leak on early fail-fast return · `panic: send on closed channel` · Order-preservation vs. streaming deadlock |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Clean-Room Workspace Provisioning
```bash
git clone https://github.com/RezaSi/go-interview-practice.git go-concurrency-interview
cd go-concurrency-interview
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
go test -race ./...
```

### Seeded Defects to Inject Before the Session
1. **Bug 1 (Unbuffered `errCh` Goroutine Leak)**: Workers send errors to `errCh := make(chan error)` (unbuffered), and the coordinator only reads `<-errCh` once and returns—leaving the remaining `N - 1` workers permanently blocked on `errCh <- err`!
2. **Bug 2 (Data Race on Shared Results Slice)**: Workers append directly to `results = append(results, res)` without a mutex or indexed slot assignment, failing `go test -race`.

---

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
> You are working on a concurrent job execution engine in Go. You have full access to the AI Assistant and `go test -race`.
>
> ### Problem Context
> Our backend service dispatches batches of I/O-bound jobs across a bounded pool of worker goroutines:
> ```go
> func ExecuteAll[T any, R any](
>     ctx context.Context,
>     maxWorkers int,
>     items []T,
>     workerFn func(ctx context.Context, item T) (R, error),
> ) ([]R, error)
> ```
> Currently, the implementation has race conditions, leaks goroutines when a job fails, and returns results in random completion order instead of matching the input slice order `items[i] -> results[i]`.
>
> ### Requirements & Invariants
> 1. **Bounded Concurrency**: At most `maxWorkers` invocations of `workerFn` may run simultaneously (if `maxWorkers <= 0`, default to `1`; if `maxWorkers > len(items)`, spawn at most `len(items)` workers).
> 2. **Input-Order Preservation**: On success, `results[i]` MUST correspond to `workerFn(ctx, items[i])` for every `0 <= i < len(items)`.
> 3. **Fail-Fast Cancellation with Zero Goroutine Leaks**:
>    - If any `workerFn` returns a non-nil error (or panics!), cancel the derived `ctx` immediately so in-flight workers can abort, stop dispatching unstarted jobs, wait for all spawned worker goroutines to exit cleanly, and return the **first** error encountered.
>    - If a worker panics with value `p`, recover the panic and convert it into an error `fmt.Errorf("worker panic: %v", p)` rather than crashing the process!
>
> ### Your Tasks
> 1. **Explore & Run Race Detector**: Inspect the worker pool files and run `go test -race ./...`.
> 2. **Uncomment Tests**: Uncomment the goroutine leak (`runtime.NumGoroutine()`), panic recovery, and order-preservation tests.
> 3. **Fix Race Conditions & Goroutine Leaks**: Implement `ExecuteAll` satisfying all 3 requirements.
> 4. **Verify Edge Cases**: Test `items = []` (empty slice), `maxWorkers = 1000` on `3` items, simultaneous errors across all workers, and parent `ctx` already cancelled before call.

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Returning From `ExecuteAll` Before `wg.Wait()` Finishes (Leaking In-Flight Goroutines)
- **What Naive AI Writes**:
  ```go
  select {
  case err := <-errCh:
      cancel()
      return nil, err // <-- BUG! Workers are still running in the background!
  case <-doneCh:
      return results, nil
  }
  ```
- **Why It Fails**: Returning immediately after `cancel()` leaves in-flight workers still executing (and holding DB transactions or temporary files) after `ExecuteAll` returns, failing the `runtime.NumGoroutine()` leak assertion and causing race conditions in caller cleanup!
- **Correct Fix**: Call `cancel()` on first error (using `sync.Once`), let active workers see `ctx.Done()` and exit, and **always wait for `wg.Wait()`** before `ExecuteAll` returns!

### Trap 2: Indexed Slot Assignment Without Mutex (Safe) vs. `append` (Data Race!)
- **What Naive AI Writes**: Either uses `results = append(results, r)` (corrupting order and racing!) or wraps `workerFn` execution inside `mu.Lock()` (destroying concurrency!).
- **Correct Fix**: Pre-allocate `results := make([]R, len(items))`. Since each job index `i` is unique, worker processing job `i` writes directly to `results[i] = res` (distinct memory locations—100% race-free without locking!).

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > *"Do not write code. Inspect the current worker pool and test suite. Identify why `go test -race` fails and where goroutines block when an error occurs."*
2. **Step 2 (`Plan`)**:
   - Pre-allocate `results := make([]R, len(items))`; use `ctx, cancel := context.WithCancel(parentCtx)`; use `sync.Once` to capture `firstErr` and call `cancel()`; guard job dispatch with `select { case jobs <- i: case <-ctx.Done(): }`; `defer recover()` inside each worker; wait for `wg.Wait()` before returning.
3. **Step 3 (`Prompt`)** & **Step 4 (`Review`)**:
   - Prompt AI with the exact design above and verify `wg.Wait()` is reached on all code paths.

---

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

| # | Criterion | Strong Hire / Hire (`Score 3–4`) | No Hire / Blind Vibe-Coder (`Score 1–2`) |
| :-: | :--- | :--- | :--- |
| **1** | **Problem Decomposition** | Designs lifecycle stages cleanly: Input validation → Pre-allocation → Dispatcher → Worker + Panic Recovery → Wait & Return. | Prompts repeatedly as each test fails without a coherent concurrency design. |
| **2** | **Prompt Context Quality** | Specifies pre-allocated `results[i]`, `sync.Once` for `firstErr` + `cancel()`, and waiting for `wg.Wait()` before return. | Prompts *"Write a worker pool in Go"*, getting generic blog code that leaks goroutines. |
| **3** | **Not Blindly Trusting AI** | Rejects AI code that returns early on `<-errCh` before `wg.Wait()` completes. | Accepts early return on `<-errCh` and fails the goroutine leak detector test. |
| **4** | **Code Reading Speed** | Immediately diagnoses the unbuffered `errCh` block and shared slice `append` race. | Needs AI to explain why `append` across goroutines is a data race. |
| **5** | **Bug & Edge-Case Discovery** | Tests `len(items) == 0`, worker panic recovery, `maxWorkers = 10000` for `2` items (doesn't spawn 9,998 idle goroutines!). | Spawns `10,000` goroutines when `maxWorkers = 10000` and `len(items) = 2`. |
| **6** | **Testing Before Claiming Done** | Runs `go test -race -count=20 ./...` before claiming done. | Never passes the `-race` flag when running `go test`. |
| **7** | **Explaining Correctness** | Explains why writing to distinct slice indices `results[i]` is race-free in Go's memory model while `append` is not. | Cannot explain why `results[i] = val` doesn't need a mutex. |

### Interviewer Probing Questions (Final 10 Minutes)
1. **Q**: *"Why is `results[i] = val` without a mutex safe under `go test -race`, whereas `results = append(results, val)` is a data race?"*  
   **Expected Answer**: Once `results := make([]R, len(items))` is allocated before spawning goroutines, the slice header (`ptr, len, cap`) is never mutated, and each index `i` is processed by exactly one goroutine, writing to a disjoint memory address `&results[i]`.
