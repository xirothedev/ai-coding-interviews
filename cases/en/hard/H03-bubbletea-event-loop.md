# H03 — Concurrent TUI Event Loop & Command Batching Deadlock

[⬅️ Back to Hard Catalog](README.md) · [🏠 Master Hub](../../../README.md)

| Attribute                    | Details                                                                                           |
| :--------------------------- | :------------------------------------------------------------------------------------------------ |
| **Case ID**                  | `H03`                                                                                             |
| **Difficulty Level**         | 🔴 **Hard** (`60–75 mins` — Senior / Staff Bar)                                                   |
| **Task Archetype**           | Concurrency + System Component Integration                                                        |
| **Source GitHub Repository** | [`charmbracelet/bubbletea`](https://github.com/charmbracelet/bubbletea)                           |
| **Target Files**             | `tea.go`, `commands.go`, `tea_test.go`, `commands_test.go`                                        |
| **Supported Languages**      | `Go`                                                                                              |
| **Hard Taxonomy Pillars**    | Pillar 3 (Message Ordering Invariants) · Pillar 4 (Goroutine Channel Deadlocks & Race Conditions) |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Source Repository & Pull Request (Confidential)

| Field                              | Value                                        |
| :--------------------------------- | :------------------------------------------- |
| **Repository**                     | `https://github.com/charmbracelet/bubbletea` |
| **Base SHA (pre-merge)**           | `c76509a9d4974207cd66255707d14f4f938f7f52`   |
| **Merge SHA (reference solution)** | `f5da8d068af74764b271a197de54e2bc2bfedb38`   |
| **Test Command**                   | `go test ./...`                              |

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/charmbracelet/bubbletea.git interview-workspace
cd interview-workspace
git checkout c76509a9d4974207cd66255707d14f4f938f7f52
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
go test ./...
```

### Reproducibility Verification

- **Base SHA (`c76509a9d497`)**: the test suite must contain at least one failing test related to the issue.
- **Merge SHA (`f5da8d068af7`)**: the same tests must pass after checkout.

### Files Changed (Reference Solution)

- tea.go

### Failing Tests to Enable

- Failing tests to enable/verify: tea_test.go. Run the test command to confirm red on Base SHA and green on Merge SHA.

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Production Incident & Feature Request: TUI Shutdown Deadlocks, Command Sequencing & Bounded Concurrency
>
> Developers building interactive terminal applications on our Elm-Architecture TUI runtime (`Init -> Update -> View`) have reported two concurrency bugs in production along with a feature request for bounded command concurrency:
>
> 1. **Shutdown Hang & Goroutine Leak Under Command Load**:
>    - When a model's `Update` method dispatches a large batch of 50+ slow background commands (`Batch(...)`) and the user quits the program (`Quit`) before those commands finish, `Program.Run()` hangs indefinitely instead of exiting cleanly.
>    - Shutdown must never panic (for example, due to concurrent producers sending on a closed channel) and must not leave leaked goroutines blocked forever trying to deliver messages after the main event loop has exited.
> 2. **Out-of-Order Execution in `Sequence`**:
>    - `Sequence(cmd1, cmd2, cmd3)` is required to execute `cmd1`, deliver its resulting message (or recursively finish any nested batch/sequence returned by `cmd1`), and only start `cmd2` after `cmd1` has completed. Currently, sequenced commands execute out of order, and fixing this must not block or deadlock the main command/event loop when `Update` emits new commands in response.
> 3. **New API — `BatchLimit(limit int, cmds ...Cmd)`**:
>    - Applications firing hundreds of network or disk commands in a single `Batch` are exhausting file descriptors.
>    - Implement and export `BatchLimit(limit int, cmds ...Cmd) Cmd`:
>      - Filters out `nil` commands (returning `nil` if no non-nil commands remain, or the single command directly if only one remains).
>      - Executes at most `limit` commands concurrently at any given time (if `limit <= 0`, clamp to `1` so execution never deadlocks).
>      - If the program shuts down (`Quit` or context cancellation) while commands are queued waiting for a concurrency slot, any unstarted commands in `BatchLimit` must abort immediately without executing.
>
> ### Acceptance Criteria
>
> 1. Explore the codebase to map how the program lifecycle, event loop, message channels, and command runners interact, and uncomment any disabled concurrency and ordering tests.
> 2. Fix the shutdown deadlock and restore strict sequential execution for `Sequence` without introducing channel panics or AB-BA deadlocks between command producers and the event loop.
> 3. Implement `BatchLimit(limit int, cmds ...Cmd)` respecting the concurrency cap, `limit <= 0` clamping, `nil` command filtering, and immediate cancellation on shutdown.
> 4. Verify your solution under the Go race detector (`go test -race -count=10 ./...`), ensuring the full suite completes in `< 5 seconds` with zero data races or goroutine leaks.

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Trusting the first plausible fix

- **What Naive AI Writes**: A minimal edit that makes the happy path pass but ignores the edge cases exercised by the real PR (`handle nested SequenceMsg in event loop`).
- **Why It Fails**: The PR touches `tea.go`; a shallow change leaves the underlying defect (ordering, caching, type resolution, or retry semantics) in place, so hidden tests still fail.
- **Correct Fix**: Reproduce the failing tests on Base SHA, then implement the same behavior change as the merged PR (study its diff), including edge cases and invariants.

### Trap 2: Over-editing unrelated code

- **What Naive AI Writes**: Refactors surrounding modules "while at it", changing public APIs.
- **Why It Fails**: Breaks callers and the hidden regression tests; the reference solution is minimal and scoped to the PR's changed lines.
- **Correct Fix**: Limit edits to the files/lines indicated by the failing tests; keep diffs small and behavior-focused.

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Trace the current behavior in `tea.go, tea_test.go` and identify why the failing tests fail on Base SHA."_
2. **Step 2 (`Plan`)**:
   - Reproduce with the test command; list the minimal files to change.
3. **Step 3 (`Prompt`)**:
   - Prompt 1: Implement the fix matching the merged PR's behavior, scoped to the failing tests.
   - Prompt 2: Add/adjust tests for edge cases (empty input, boundary values, error paths).
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Run the full test command; confirm all previously-failing tests pass and no regressions.

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

|   #   | Criterion                        | Strong Hire / Hire (`Score 3–4`)                                                                                                 | No Hire / Blind Vibe-Coder (`Score 1–2`)                                                                       |
| :---: | :------------------------------- | :------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------- |
| **1** | **Problem Decomposition**        | Maps the channel topology (`p.cmds` vs `p.msgs`) first; fixes shutdown cancellation before adding `BatchLimit`.                  | Tries to fix deadlock, `Sequence`, and `BatchLimit` in one prompt without understanding `eventLoop`.           |
| **2** | **Prompt Context Quality**       | Specifies Go concurrency invariants: _"Do not close `p.msgs`; use `select` with `<-p.ctx.Done()` and track goroutines in `wg`."_ | Prompts _"Fix the deadlock in `tea.go`"_ with no mention of `p.ctx` or channel ownership.                      |
| **3** | **Not Blindly Trusting AI**      | Immediately rejects any AI diff that calls `close(p.msgs)` or runs `sequenceMsg` synchronously on the `p.cmds` loop.             | Applies `close(p.msgs)` and hits `panic: send on closed channel` during `-race` tests.                         |
| **4** | **Code Reading Speed**           | Traces `Run() -> eventLoop() -> handleCommands()` in `tea.go` within 8 minutes.                                                  | Confuses `tea.Cmd` (a function `func() Msg`) with `tea.Msg` (the resulting value).                             |
| **5** | **Bug & Edge-Case Discovery**    | Tests `BatchLimit` with `limit = 0`, `nil` commands in the slice, nested `Batch` inside `Sequence`, and immediate `Quit()`.      | Forgets to filter out `nil` `Cmd` elements or crashes when `limit <= 0` (`make(chan struct{}, 0)` deadlocks!). |
| **6** | **Testing Before Claiming Done** | Runs `go test -race -count=10 ./...` to prove determinism under scheduler jitter.                                                | Runs `go test` once without `-race` and declares victory.                                                      |
| **7** | **Explaining Correctness**       | Clearly explains AB-BA channel deadlocks between `p.cmds` and `p.msgs` and how semaphore acquisition with `ctx.Done()` works.    | Cannot explain why `make(chan struct{}, 0)` blocks forever when `limit == 0`.                                  |

### Interviewer Probing Questions (Final 10 Minutes)

1. **Q**: _"What happens in your `BatchLimit` implementation if a caller passes `limit = 0` or `limit = -1`?"_  
   **Expected Answer**: In Go, `make(chan struct{}, 0)` creates an **unbuffered** channel, which would permanently block on `sem <- struct{}{}` because there is no receiver until a worker finishes! Clamping `if limit < 1 { limit = 1 }` ensures a buffered channel of size at least 1.
2. **Q**: _"Why would running `sequenceMsg` directly inside the `for select` loop of `handleCommands` cause a deadlock?"_  
   **Expected Answer**: If a command inside the sequence emits a message whose `Update()` handler returns a new `Cmd`, `eventLoop` tries to send that `Cmd` to `p.cmds`. If `handleCommands` is busy waiting for the next step of the sequence instead of reading from `p.cmds`, both goroutines deadlock.
