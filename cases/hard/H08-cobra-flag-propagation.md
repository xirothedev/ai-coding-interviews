# H08 — Hierarchical CLI Flag Propagation & PersistentPreRun Hook Shadowing

[⬅️ Back to Hard Catalog](README.md) · [🏠 Master Hub](../../README.md)

| Attribute                    | Details                                                                                                                  |
| :--------------------------- | :----------------------------------------------------------------------------------------------------------------------- |
| **Case ID**                  | `H08`                                                                                                                    |
| **Difficulty Level**         | 🔴 **Hard** (`60–75 mins` — Senior / Staff Bar)                                                                          |
| **Task Archetype**           | Legacy Refactoring + Backwards-Compatibility Invariants                                                                  |
| **Source GitHub Repository** | [`spf13/cobra`](https://github.com/spf13/cobra)                                                                          |
| **Target Files**             | `command.go`, `flag_groups.go`, `command_test.go`, `flag_groups_test.go`                                                 |
| **Supported Languages**      | `Go`                                                                                                                     |
| **Hard Taxonomy Pillars**    | Pillar 1 (Deceptive Tree Traversal) · Pillar 3 (Backwards-Compatibility Contracts) · Pillar 4 (Partial Failure Rollback) |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/spf13/cobra.git cobra-interview
cd cobra-interview
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
go test ./...
```

### Seeded Defects to Inject Before the Session

1. **Bug 1 (Persistent Flag Group Validation Timing in `flag_groups.go` / `command.go`)**: When a parent command defines `PersistentFlags().String("env", "", "")` and a child command calls `MarkFlagsMutuallyExclusive("env", "local")`, `validateFlagGroups()` either runs before `MergePersistentFlags()` or fails to reset merged flag state when `Execute()` is invoked a second time in tests.
2. **Bug 2 (`EnableTraverseRunHooks` Asymmetrical `PersistentPostRun` Execution)**: In `Command.execute()` (`command.go`), when `EnableTraverseRunHooks = true` runs `PersistentPreRunE` from `root -> parent -> child`, if `parent.PersistentPreRunE` returns an error, cleanup hooks (`PersistentPostRunE`) either don't run for `root` or erroneously run for `child` (whose `PreRun` never executed!).

---

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
>
> You are working inside `spf13/cobra`, the CLI library powering Kubernetes (`kubectl`), Docker, and GitHub CLI (`gh`). You have full access to the AI Assistant and `go test ./...`.
>
> ### Problem Context
>
> Because thousands of CLIs depend on Cobra, **strict backwards compatibility** with existing behavior is mandatory while fixing two hierarchical command bugs:
>
> 1. **Cross-Level Flag Group Validation (`flag_groups.go` & `command.go`)**:
>    - Commands can declare flag groups via `MarkFlagsRequiredTogether(names...)`, `MarkFlagsMutuallyExclusive(names...)`, and `MarkFlagsOneRequired(names...)`.
>    - **Bug**: When a child subcommand declares a flag group referencing a flag defined on its parent's `PersistentFlags()` alongside a flag on the child's local `Flags()`, validation either fails to see the parent persistent flag or leaks `Changed` flag state across repeated `cmd.Execute()` calls in test suites.
> 2. **Hierarchical Lifecycle Hook Traversal & Symmetrical Rollback (`command.go`)**:
>    - **Default Mode (`EnableTraverseRunHooks == false`)**: Must preserve legacy Cobra behavior—walk up `c.Parent()` from the target command and execute **only the first (nearest)** `PersistentPreRun(E)` found, and similarly only the nearest `PersistentPostRun(E)`.
>    - **Traversal Mode (`EnableTraverseRunHooks == true`)**:
>      - Execute `PersistentPreRun(E)` in top-down ancestor order: **`Root → Parent → Child`**.
>      - Execute `PersistentPostRun(E)` in reverse bottom-up order: **`Child → Parent → Root`** (simulating middleware `defer` unwinding!).
>      - **Partial Failure Rollback Rule**: If `Root.PersistentPreRunE` succeeds, and `Parent.PersistentPreRunE` returns an `err`, `Child.PersistentPreRunE` and `Child.RunE` MUST NOT run, AND `Root.PersistentPostRun(E)` MUST still run to clean up resources initialized by `Root` (while `Parent` and `Child` `PostRun` hooks do NOT run)!
>
> ### Your Tasks
>
> 1. **Explore & Trace**: Inspect `Command.execute()`, `MergePersistentFlags()`, and `validateFlagGroups()` in `command.go` and `flag_groups.go`.
> 2. **Run & Uncomment Tests**: Run `go test ./...` and uncomment the failing tests in `command_test.go` and `flag_groups_test.go`.
> 3. **Fix Flag Group Merging & Symmetrical Hook Unwinding**: Implement fixes in `command.go` and `flag_groups.go` without breaking any of the 200+ existing unit tests.
> 4. **Verify Edge Cases**: Test 4-level command trees (`root -> org -> repo -> deploy`) where level 2 fails in `PersistentPreRunE`, and where `PersistentPostRunE` also returns an error (preserving the primary error or joining errors cleanly).

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Breaking Default Cobra Shadowing (`EnableTraverseRunHooks == false`)

- **What Naive AI Writes**:
  - When prompted to run `PersistentPreRunE` from `Root -> Parent -> Child`, the AI replaces the `for p := c; p != nil; p = p.Parent()` `break` statement unconditionally without checking `EnableTraverseRunHooks`!
- **Why It Fails**: 25+ existing tests in `command_test.go` fail immediately because default Cobra behavior requires `break` after the first non-nil `PersistentPreRun` is found!
- **Correct Fix**: Guard the root-to-child traversal and unwind stack behind `if EnableTraverseRunHooks` (while keeping the `break`-on-first-match loop for `EnableTraverseRunHooks == false`).

### Trap 2: Running `PersistentPostRun` in `Root -> Child` Order or Running `Child.PostRun` After `Parent.PreRun` Fails

- **What Naive AI Writes**:
  ```go
  // Naive AI PostRun loop:
  for p := c; p != nil; p = p.Parent() {
      if p.PersistentPostRunE != nil {
          p.PersistentPostRunE(c, argWoFlags)
      }
  }
  ```
- **Why It Fails**:
  1. If `Parent.PersistentPreRunE` returned an error, `Command.execute()` returned early at line 915—so `Root.PersistentPostRunE` **never ran**, leaking whatever DB/telemetry connection `Root.PersistentPreRunE` opened!
  2. If the AI puts `defer` or runs `PostRun` on error for _all_ ancestors from `c` upward, `Child.PersistentPostRunE` runs even though `Child.PersistentPreRunE` never ran!
- **Correct Fix**: As each ancestor `p`'s `PersistentPreRun(E)` succeeds (from `Root` down to `Child`), push `p` onto an `executedPreRunAncestors []*Command` stack. Use a `defer` (or cleanup block before returning from `execute`) that iterates `executedPreRunAncestors` in **reverse (LIFO)** order (`i := len(stack) - 1; i >= 0; i--`) and invokes `PersistentPostRun(E)`.

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Read `command.go` around `execute()` and `flag_groups.go` around `validateFlagGroups()`. Show exact line numbers where `MergePersistentFlags()`, `PersistentPreRunE`, and `PersistentPostRunE` are called, and how `EnableTraverseRunHooks` currently works."_
2. **Step 2 (`Plan`)**:
   - Candidate plans the LIFO `executedAncestors` stack for `EnableTraverseRunHooks` and checks `MergePersistentFlags()` placement before `validateFlagGroups()`.
3. **Step 3 (`Prompt`)**:
   - Prompt 1: Fix `flag_groups.go` / `MergePersistentFlags()` ordering.
   - Prompt 2: Implement the LIFO unwind stack for `PersistentPreRun(E)` / `PersistentPostRun(E)` when `EnableTraverseRunHooks == true`.
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Run `go test ./...` and verify all legacy tests still pass.

---

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

|   #   | Criterion                        | Strong Hire / Hire (`Score 3–4`)                                                                                                    | No Hire / Blind Vibe-Coder (`Score 1–2`)                                                                                                                   |
| :---: | :------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **1** | **Problem Decomposition**        | Separates flag group merging (`flag_groups.go`) from hook lifecycle unwinding (`command.go`).                                       | Dumps both problems into one prompt and breaks `command.go`.                                                                                               |
| **2** | **Prompt Context Quality**       | Explicitly specifies `EnableTraverseRunHooks` gating and the LIFO stack of _succeeded_ `PreRun` ancestors.                          | Prompts _"Make PersistentPreRun run from root to child"_, breaking 25 existing tests.                                                                      |
| **3** | **Not Blindly Trusting AI**      | Audits how errors from `PreRunE`, `RunE`, and `PostRunE` prioritize (primary error vs cleanup error).                               | Accepts AI code that overwrites a `RunE` error with `nil` from a succeeding `PostRunE`! (`err = p.PersistentPostRunE(...)` overwriting non-nil `runErr`!). |
| **4** | **Code Reading Speed**           | Finds `EnableTraverseRunHooks` and `MergePersistentFlags()` in `command.go` within 5 minutes.                                       | Doesn't notice `EnableTraverseRunHooks` already exists in the package.                                                                                     |
| **5** | **Bug & Edge-Case Discovery**    | Tests `RunE` returning an error while `PostRunE` returns `nil` (must still return `RunE`'s error!) and mid-chain `PreRunE` failure. | Overwrites `err` in the cleanup loop so `Execute()` returns `nil` even when `RunE` failed!                                                                 |
| **6** | **Testing Before Claiming Done** | Runs full `go test ./...` after every edit and adds multi-level tree table tests.                                                   | Only runs a single `-run TestHook` test and misses regressions in `command_test.go`.                                                                       |
| **7** | **Explaining Correctness**       | Explains the middleware/RAII stack unwind invariant (`push` on `PreRun` success, `pop` on `PostRun`).                               | Cannot explain what happens when both `RunE` and `PostRunE` return errors.                                                                                 |

### Interviewer Probing Questions (Final 10 Minutes)

1. **Q**: _"Suppose `Child.RunE` returns `ErrDeployFailed`, and then during unwinding, `Root.PersistentPostRunE` succeeds and returns `nil`. What happens if your cleanup code writes `err = p.PersistentPostRunE(...)`?"_  
   **Expected Answer**: It would overwrite `ErrDeployFailed` with `nil`, causing `cmd.Execute()` to report success (`nil`) when the command actually failed! The cleanup hook error should only be assigned if the primary `err == nil` (or combined via `errors.Join`).
