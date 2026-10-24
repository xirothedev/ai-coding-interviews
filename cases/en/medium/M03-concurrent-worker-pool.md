# M03 — Concurrent Worker Pool & Graceful Context Cancellation

[⬅️ Back to Medium Catalog](README.md) · [🏠 Master Hub](../../../README.md)

| Attribute                    | Details                                                                                                                                                                                                                                                                                              |
| :--------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Case ID**                  | `M03`                                                                                                                                                                                                                                                                                                |
| **Difficulty Level**         | 🟡 **Medium** (`45–60 mins` — Standard SWE Bar)                                                                                                                                                                                                                                                      |
| **Task Archetype**           | System Component Integration & Concurrency                                                                                                                                                                                                                                                           |
| **Source GitHub Repository** | [`sourcegraph/conc`](https://github.com/sourcegraph/conc) (`pool/context_pool.go`, `pool/result_context_pool.go`, `iter/map.go`) · [`RezaSi/go-interview-practice`](https://github.com/RezaSi/go-interview-practice) (`challenge-11/solution-template.go`, `challenge-11/solution-template_test.go`) |
| **Target Files**             | `pool/context_pool.go`, `pool/result_context_pool.go`, `iter/map.go` _(or `challenge-11/solution-template.go` & `challenge-11/solution-template_test.go`)_                                                                                                                                           |
| **Supported Languages**      | `Go` _(Primary)_, `TypeScript`, `Python` (`asyncio`), `Rust` (`tokio`)                                                                                                                                                                                                                               |
| **Primary AI Traps**         | Calling `cancel()` _before_ `addErr(err)` (causing surviving workers to record `context.Canceled` instead of the real root error!) · Goroutine leak on early fail-fast return · Shared slice `append` data race                                                                                      |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Source Repository & Pull Request (Confidential)

| Field                              | Value                                      |
| :--------------------------------- | :----------------------------------------- |
| **Repository**                     | `https://github.com/sourcegraph/conc`      |
| **Base SHA (pre-merge)**           | `30a99cd85b339bce498627582d604740385a3ba8` |
| **Merge SHA (reference solution)** | `8427ccd11dde5f56ccacfbbd184f42ce865d2f0d` |
| **Test Command**                   | `go test ./...`                            |

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/sourcegraph/conc.git interview-workspace
cd interview-workspace
git checkout 30a99cd85b339bce498627582d604740385a3ba8
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
go test ./...
```

### Reproducibility Verification

- **Base SHA (`30a99cd85b33`)**: the test suite must contain at least one failing test related to the issue.
- **Merge SHA (`8427ccd11dde`)**: the same tests must pass after checkout.

### Files Changed (Reference Solution)

- pool/result_context_pool.go, pool/result_pool.go

### Failing Tests to Enable

- Re-enable any commented-out or skipped tests covering the issue; run `go test ./...` to confirm red on Base SHA and green on Merge SHA.

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
>
> You are working on a concurrent job execution engine in Go. You have full access to the AI Assistant and `go test -race`.
>
> ### Problem Context
>
> Our backend service dispatches batches of I/O-bound jobs across a bounded pool of worker goroutines:
>
> ```go
> func ExecuteAll[T any, R any](
>     ctx context.Context,
>     maxWorkers int,
>     items []T,
>     workerFn func(ctx context.Context, item T) (R, error),
> ) ([]R, error)
> ```
>
> Currently, the implementation has race conditions, leaks goroutines when a job fails, and returns results in random completion order instead of matching the input slice order `items[i] -> results[i]`.
>
> ### Requirements & Invariants
>
> 1. **Bounded Concurrency**: At most `maxWorkers` invocations of `workerFn` may run simultaneously (if `maxWorkers <= 0`, default to `1`; if `maxWorkers > len(items)`, spawn at most `len(items)` workers).
> 2. **Input-Order Preservation**: On success, `results[i]` MUST correspond to `workerFn(ctx, items[i])` for every `0 <= i < len(items)`.
> 3. **Fail-Fast Cancellation with Zero Goroutine Leaks**:
>    - If any `workerFn` returns a non-nil error (or panics!), cancel the derived `ctx` immediately so in-flight workers can abort, stop dispatching unstarted jobs, wait for all spawned worker goroutines to exit cleanly, and return the **first** error encountered.
>    - If a worker panics with value `p`, recover the panic and convert it into an error `fmt.Errorf("worker panic: %v", p)` rather than crashing the process!
>
> ### Your Tasks
>
> 1. **Explore & Run Race Detector**: Inspect the worker pool files and run `go test -race ./...`.
> 2. **Uncomment Tests**: Uncomment the goroutine leak (`runtime.NumGoroutine()`), panic recovery, and order-preservation tests.
> 3. **Fix Race Conditions & Goroutine Leaks**: Implement `ExecuteAll` satisfying all 3 requirements.
> 4. **Verify Edge Cases**: Test `items = []` (empty slice), `maxWorkers = 1000` on `3` items, simultaneous errors across all workers, and parent `ctx` already cancelled before call.

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Returning Before `wg.Wait()` Finishes OR Calling `cancel()` Before Recording `firstErr` (`addErr`)

- **What Naive AI Writes**:
  ```go
  if err != nil {
      cancel()          // <-- BUG 1: Wakes sibling workers with ctx.Err() == context.Canceled BEFORE err is saved!
      once.Do(func() { firstErr = err })
      return nil, err   // <-- BUG 2: Returns while in-flight workers are still running in the background!
  }
  ```
- **Why It Fails**:
  1. As documented in `sourcegraph/conc/pool/context_pool.go`, if a failing worker calls `cancel()` _before_ recording `err` (via `addErr(err)` / `once.Do`), another worker blocked on `<-ctx.Done()` can wake up immediately, return `ctx.Err()` (`context.Canceled`), and win the race to `once.Do`, causing `ExecuteAll` to return `context.Canceled` instead of the real database/network error!
  2. Returning immediately after `cancel()` leaves in-flight workers still executing after `ExecuteAll` returns, failing `runtime.NumGoroutine()` leak checks!
- **Correct Fix**: Record the error (`addErr(err)` / `once.Do`) **before** calling `cancel()`, and **always wait for `wg.Wait()`** before `ExecuteAll` returns!

### Trap 2: Indexed Slot Assignment Without Mutex (Safe) vs. `append` (Data Race!)

- **What Naive AI Writes**: Either uses `results = append(results, r)` (corrupting order and racing!) or wraps `workerFn` execution inside `mu.Lock()` (destroying concurrency!).
- **Correct Fix**: Pre-allocate `results := make([]R, len(items))`. Since each job index `i` is unique, worker processing job `i` writes directly to `results[i] = res` (distinct memory locations—100% race-free without locking!).

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Inspect the current worker pool and test suite. Identify why `go test -race` fails and where goroutines block when an error occurs."_
2. **Step 2 (`Plan`)**:
   - Pre-allocate `results := make([]R, len(items))`; use `ctx, cancel := context.WithCancel(parentCtx)`; use `sync.Once` to capture `firstErr` and call `cancel()`; guard job dispatch with `select { case jobs <- i: case <-ctx.Done(): }`; `defer recover()` inside each worker; wait for `wg.Wait()` before returning.
3. **Step 3 (`Prompt`)** & **Step 4 (`Review`)**:
   - Prompt AI with the exact design above and verify `wg.Wait()` is reached on all code paths.

---

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

|   #   | Criterion                        | Strong Hire / Hire (`Score 3–4`)                                                                                            | No Hire / Blind Vibe-Coder (`Score 1–2`)                                                |
| :---: | :------------------------------- | :-------------------------------------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------- |
| **1** | **Problem Decomposition**        | Designs lifecycle stages cleanly: Input validation → Pre-allocation → Dispatcher → Worker + Panic Recovery → Wait & Return. | Prompts repeatedly as each test fails without a coherent concurrency design.            |
| **2** | **Prompt Context Quality**       | Specifies pre-allocated `results[i]`, `sync.Once` for `firstErr` + `cancel()`, and waiting for `wg.Wait()` before return.   | Prompts _"Write a worker pool in Go"_, getting generic blog code that leaks goroutines. |
| **3** | **Not Blindly Trusting AI**      | Rejects AI code that returns early on `<-errCh` before `wg.Wait()` completes.                                               | Accepts early return on `<-errCh` and fails the goroutine leak detector test.           |
| **4** | **Code Reading Speed**           | Immediately diagnoses the unbuffered `errCh` block and shared slice `append` race.                                          | Needs AI to explain why `append` across goroutines is a data race.                      |
| **5** | **Bug & Edge-Case Discovery**    | Tests `len(items) == 0`, worker panic recovery, `maxWorkers = 10000` for `2` items (doesn't spawn 9,998 idle goroutines!).  | Spawns `10,000` goroutines when `maxWorkers = 10000` and `len(items) = 2`.              |
| **6** | **Testing Before Claiming Done** | Runs `go test -race -count=20 ./...` before claiming done.                                                                  | Never passes the `-race` flag when running `go test`.                                   |
| **7** | **Explaining Correctness**       | Explains why writing to distinct slice indices `results[i]` is race-free in Go's memory model while `append` is not.        | Cannot explain why `results[i] = val` doesn't need a mutex.                             |

### Interviewer Probing Questions (Final 10 Minutes)

1. **Q**: _"Why is `results[i] = val` without a mutex safe under `go test -race`, whereas `results = append(results, val)` is a data race?"_  
   **Expected Answer**: Once `results := make([]R, len(items))` is allocated before spawning goroutines, the slice header (`ptr, len, cap`) is never mutated, and each index `i` is processed by exactly one goroutine, writing to a disjoint memory address `&results[i]`.

2. **Q**: _"Why must `cancel()` be called only after recording `firstErr`?"_
   **Expected Answer**: Otherwise the first error is lost and the pool reports success despite a failure.
