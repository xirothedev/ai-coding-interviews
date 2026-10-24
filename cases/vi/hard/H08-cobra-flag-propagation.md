# H08 — Hierarchical CLI Flag Propagation & PersistentPreRun Hook Shadowing

[⬅️ Back to Hard Catalog](README.md) · [🏠 Master Hub](../../../README.md)

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

### Source Repository & Pull Request (Confidential)

| Field                              | Value                                      |
| :--------------------------------- | :----------------------------------------- |
| **Repository**                     | `https://github.com/spf13/cobra`           |
| **Base SHA (pre-merge)**           | `dbf85f6104904d539cabceebec234e817fa0df0c` |
| **Merge SHA (reference solution)** | `22b617914c8890ba20db7ceafcdc2ef4ca4817d3` |
| **Test Command**                   | `go test ./...`                            |

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/spf13/cobra.git interview-workspace
cd interview-workspace
git checkout dbf85f6104904d539cabceebec234e817fa0df0c
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
go test ./...
```

### Reproducibility Verification

- **Base SHA (`dbf85f610490`)**: the test suite must contain at least one failing test related to the issue.
- **Merge SHA (`22b617914c88`)**: the same tests must pass after checkout.

### Files Changed (Reference Solution)

- command.go

### Failing Tests to Enable

- Failing tests to enable/verify: command_test.go. Run the test command to confirm red on Base SHA and green on Merge SHA.

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Bug Report: CLI Flag Propagation & Shadowing
>
> Child commands do not correctly handle flags that shadow parent persistent flags, and flag groups/completion have issues.
>
> ### Requirements
>
> - Show flags that shadow parent persistent flags in child help.
> - Propagate flags correctly through command hierarchy.
> - Support flag groups and completion consistently.
>
> ### Acceptance Criteria
>
> 1. Trace the command and flag handling.
> 2. Fix shadowing and propagation.
> 3. Verify with nested commands and flag groups.

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Trusting the first plausible fix

- **What Naive AI Writes**: A minimal edit that makes the happy path pass but ignores the edge cases exercised by the real PR (`show flags that shadow parent persistent flag in child help`).
- **Why It Fails**: The PR touches `command.go`; a shallow change leaves the underlying defect (ordering, caching, type resolution, or retry semantics) in place, so hidden tests still fail.
- **Correct Fix**: Reproduce the failing tests on Base SHA, then implement the same behavior change as the merged PR (study its diff), including edge cases and invariants.

### Trap 2: Over-editing unrelated code

- **What Naive AI Writes**: Refactors surrounding modules "while at it", changing public APIs.
- **Why It Fails**: Breaks callers and the hidden regression tests; the reference solution is minimal and scoped to the PR's changed lines.
- **Correct Fix**: Limit edits to the files/lines indicated by the failing tests; keep diffs small and behavior-focused.

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Trace the current behavior in `command.go, command_test.go` and identify why the failing tests fail on Base SHA."_
2. **Step 2 (`Plan`)**:
   - Reproduce with the test command; list the minimal files to change.
3. **Step 3 (`Prompt`)**:
   - Prompt 1: Implement the fix matching the merged PR's behavior, scoped to the failing tests.
   - Prompt 2: Add/adjust tests for edge cases (empty input, boundary values, error paths).
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Run the full test command; confirm all previously-failing tests pass and no regressions.

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

|   #   | Criterion                        | Strong Hire / Hire (`Score 3–4`)                                                                                                    | No Hire / Blind Vibe-Coder (`Score 1–2`)                                                                                                                   |
| :---: | :------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **1** | **Problem Decomposition**        | Separates flag group merging (`flag_groups.go`) from hook lifecycle unwinding (`command.go`).                                       | Dumps both problems into one prompt and breaks `command.go`.                                                                                               |
| **2** | **Prompt Context Quality**       | Explicitly specifies `EnableTraverseRunHooks` gating and the LIFO stack of _succeeded_ `PreRun` ancestors.                          | Prompts _"Make PersistentPreRun run from root to child"_, breaking 25 existing tests.                                                                      |
| **3** | **Not Blindly Trusting AI**      | Audits how errors from `PreRunE`, `RunE`, and `PostRunE` prioritize (primary error vs cleanup error).                               | Accepts AI code that overwrites a `RunE` error with `nil` from a succeeding `PostRunE`! (`err = p.PersistentPostRunE(...)` overwriting non-nil `runErr`!). |
| **4** | **Code Reading Speed**           | Finds `EnableTraverseRunHooks` and `mergePersistentFlags()` in `command.go` within 5 minutes.                                       | Doesn't notice `EnableTraverseRunHooks` already exists in the package.                                                                                     |
| **5** | **Bug & Edge-Case Discovery**    | Tests `RunE` returning an error while `PostRunE` returns `nil` (must still return `RunE`'s error!) and mid-chain `PreRunE` failure. | Overwrites `err` in the cleanup loop so `Execute()` returns `nil` even when `RunE` failed!                                                                 |
| **6** | **Testing Before Claiming Done** | Runs full `go test ./...` after every edit and adds multi-level tree table tests.                                                   | Only runs a single `-run TestHook` test and misses regressions in `command_test.go`.                                                                       |
| **7** | **Explaining Correctness**       | Explains the middleware/RAII stack unwind invariant (`push` on `PreRun` success, `pop` on `PostRun`).                               | Cannot explain what happens when both `RunE` and `PostRunE` return errors.                                                                                 |

### Interviewer Probing Questions (Final 10 Minutes)

1. **Q**: _"Suppose `Child.RunE` returns `ErrDeployFailed`, and then during unwinding, `Root.PersistentPostRunE` succeeds and returns `nil`. What happens if your cleanup code writes `err = p.PersistentPostRunE(...)`?"_  
   **Expected Answer**: It would overwrite `ErrDeployFailed` with `nil`, causing `cmd.Execute()` to report success (`nil`) when the command actually failed! The cleanup hook error should only be assigned if the primary `err == nil` (or combined via `errors.Join`).

2. **Q**: _"Why must default Cobra hook shadowing be preserved?"_
   **Expected Answer**: Breaking it runs parent hooks unexpectedly and violates the documented command lifecycle.
