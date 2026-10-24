# H03 — Concurrent TUI Event Loop & Command Batching Deadlock

> 🌐 Language: **English** · <a href="vi/H03-bubbletea-event-loop">Tiếng Việt</a>

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

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/charmbracelet/bubbletea.git bubbletea-interview
cd bubbletea-interview
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
go test -race ./...
```

### Seeded Defects to Inject Before the Session

In `tea.go` and `commands.go`:

1. **Bug 1 (Unconditional Channel Send Deadlock on Shutdown)**: In `handleCommands()` (where `Cmd` goroutines send `p.msgs <- msg`), remove the `case <-p.ctx.Done():` branch from the `select` statement so `p.msgs <- msg` blocks forever if `eventLoop()` has already exited upon receiving `QuitMsg`.
2. **Bug 2 (`Sequence` Running Concurrently Instead of Sequentially)**: In `commands.go` / `tea.go`, handle `sequenceMsg` by spawning goroutines in parallel (like `BatchMsg`), breaking the deterministic execution order contract of `tea.Sequence(cmd1, cmd2, cmd3)`.
3. **Commented Tests**: Comment out upstream `TestSequence` and `TestBatch` in `commands_test.go`, and stage `TestProgramQuitDeadlockUnderLoad` (in `tea_test.go`) and `TestSequenceOrderGuarantee` (in `commands_test.go`) as commented-out tests during the interviewer setup step.

---

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

### Trap 1: Closing `p.msgs` When `QuitMsg` Arrives (`panic: send on closed channel`)

- **What Naive AI Writes**:
  ```go
  case QuitMsg:
      close(p.msgs) // <-- FATAL PANIC!
      return model, nil
  ```
- **Why It Fails**: In Go, closing a channel while multiple producer goroutines (`Cmd` runners and external `p.Send()` callers) are still sending to `p.msgs` causes an immediate runtime crash: `panic: send on closed channel`.
- **Correct Fix**: Never close `p.msgs` while producers exist. Instead, cancel `p.ctx` (`cancel()`) when `eventLoop` exits, and wrap every channel send in `select`:
  ```go
  select {
  case p.msgs <- msg:
  case <-p.ctx.Done():
      return
  }
  ```

### Trap 2: Executing `Sequence` Synchronously Inside the `cmds` Reader Loop

- **What Naive AI Writes**:
  ```go
  // Inside the single goroutine reading `case cmd := <-p.cmds:`
  case sequenceMsg:
      for _, c := range msg {
          p.msgs <- c() // <-- Deadlocks if c() returns another BatchMsg or SequenceMsg!
      }
  ```
- **Why It Fails**: If `handleCommands` blocks its own `for select` loop waiting for `c()` to complete, and `Update()` responds to `c()`'s message by queuing a new `Cmd` onto `p.cmds` (an unbuffered channel!), `eventLoop` blocks writing to `p.cmds` while `handleCommands` is blocked writing to `p.msgs` — a classic **AB-BA channel deadlock**!
- **Correct Fix**: Spawn a managed goroutine (`wg.Add(1)`) for the `sequenceMsg` that iterates through the slice sequentially, respecting `p.ctx.Done()` at each step and delegating nested `BatchMsg`/`sequenceMsg` properly.

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Trace all producers and consumers of `p.msgs` and `p.cmds` in `tea.go`. Identify which goroutine owns closing each channel and how `wg sync.WaitGroup` tracks running commands during shutdown."_
2. **Step 2 (`Plan`)**:
   - Candidate notes that `p.ctx.Done()` is the shutdown broadcast signal, so all `p.msgs <-` and `p.cmds <-` sends must `select` on `<-p.ctx.Done()`.
3. **Step 3 (`Prompt`)**:
   - Prompt 1: Fix `handleCommands` and `Send` channel sends + `sequenceMsg` goroutine handling in `tea.go`.
   - Prompt 2: Add `BatchLimit(limit int, cmds ...Cmd)` using a semaphore channel (`sem := make(chan struct{}, limit)`) that selects on `<-p.ctx.Done()` before acquiring a token.
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Candidate audits for any `close(p.msgs)` or unguarded channel sends, then runs `go test -race -count=10 ./...`.

---

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
