# H07 — Async Query Cache Deduplication & Optimistic Rollback Race

[⬅️ Back to Hard Catalog](README.md) · [🏠 Master Hub](../../../README.md)

| Attribute                    | Details                                                                                                                                                                  |
| :--------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Case ID**                  | `H07`                                                                                                                                                                    |
| **Difficulty Level**         | 🔴 **Hard** (`60–75 mins` — Senior / Staff Bar)                                                                                                                          |
| **Task Archetype**           | Concurrency + State Machine Integration                                                                                                                                  |
| **Source GitHub Repository** | [`TanStack/query`](https://github.com/TanStack/query) (`packages/query-core`)                                                                                            |
| **Target Files**             | `packages/query-core/src/query.ts`, `packages/query-core/src/queryObserver.ts`, `packages/query-core/src/retryer.ts`, `packages/query-core/src/__tests__/query.test.tsx` |
| **Supported Languages**      | `TypeScript`                                                                                                                                                             |
| **Hard Taxonomy Pillars**    | Pillar 3 (State Machine Invariants) · Pillar 4 (Async Race Conditions & Cancellation)                                                                                    |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Source Repository & Pull Request (Confidential)

| Field                              | Value                                      |
| :--------------------------------- | :----------------------------------------- |
| **Repository**                     | `https://github.com/TanStack/query`        |
| **Base SHA (pre-merge)**           | `8c3f218b13b70424bb9d9733b2e60e5f6c1f06a8` |
| **Merge SHA (reference solution)** | `f608f933a36da30670082e90d0a56b2569290563` |
| **Test Command**                   | `pnpm test`                                |

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/TanStack/query.git interview-workspace
cd interview-workspace
git checkout 8c3f218b13b70424bb9d9733b2e60e5f6c1f06a8
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
pnpm test
```

### Reproducibility Verification

- **Base SHA (`8c3f218b13b7`)**: the test suite must contain at least one failing test related to the issue.
- **Merge SHA (`f608f933a36d`)**: the same tests must pass after checkout.

### Files Changed (Reference Solution)

- packages/query-core/src/queryObserver.ts

### Failing Tests to Enable

- Failing tests to enable/verify: queryObserver.test.tsx. Run the test command to confirm red on Base SHA and green on Merge SHA.

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Bug Report: Optimistic Query Fetch Options
>
> Optimistic updates use default options instead of the supplied query options, causing incorrect fetch behavior.
>
> ### Requirements
>
> - Use supplied options for optimistic fetches.
> - Ensure rollback on failed mutations.
> - Maintain consistency between optimistic and actual state.
>
> ### Acceptance Criteria
>
> 1. Trace the query observer.
> 2. Fix option propagation for optimistic fetches.
> 3. Verify with mutation scenarios.

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Trusting the first plausible fix

- **What Naive AI Writes**: A minimal edit that makes the happy path pass but ignores the edge cases exercised by the real PR (`use supplied options for optimistic fetches`).
- **Why It Fails**: The PR touches `packages/query-core/src/queryObserver.ts`; a shallow change leaves the underlying defect (ordering, caching, type resolution, or retry semantics) in place, so hidden tests still fail.
- **Correct Fix**: Reproduce the failing tests on Base SHA, then implement the same behavior change as the merged PR (study its diff), including edge cases and invariants.

### Trap 2: Over-editing unrelated code

- **What Naive AI Writes**: Refactors surrounding modules "while at it", changing public APIs.
- **Why It Fails**: Breaks callers and the hidden regression tests; the reference solution is minimal and scoped to the PR's changed lines.
- **Correct Fix**: Limit edits to the files/lines indicated by the failing tests; keep diffs small and behavior-focused.

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Trace the current behavior in `packages/query-core/src/queryObserver.ts, queryObserver.test.tsx` and identify why the failing tests fail on Base SHA."_
2. **Step 2 (`Plan`)**:
   - Reproduce with the test command; list the minimal files to change.
3. **Step 3 (`Prompt`)**:
   - Prompt 1: Implement the fix matching the merged PR's behavior, scoped to the failing tests.
   - Prompt 2: Add/adjust tests for edge cases (empty input, boundary values, error paths).
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Run the full test command; confirm all previously-failing tests pass and no regressions.

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

|   #   | Criterion                        | Strong Hire / Hire (`Score 3–4`)                                                                                                              | No Hire / Blind Vibe-Coder (`Score 1–2`)                                                            |
| :---: | :------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------- |
| **1** | **Problem Decomposition**        | Separates the observer `AbortSignal` lifecycle from the optimistic state reducer model.                                                       | Mixes observer cancellation and mutation state into a single tangled prompt.                        |
| **2** | **Prompt Context Quality**       | Explicitly tells AI _not_ to use point-in-time snapshot restoration and specifies the `baseState + pendingUpdaters.reduce(...)` architecture. | Asks AI _"Fix overlapping optimistic updates"_, receiving broken snapshot code.                     |
| **3** | **Not Blindly Trusting AI**      | Immediately rejects snapshot rollback by tracing the `(M1 fail, M2 fail)` counterexample on paper/comments.                                   | Accepts AI's snapshot code or timestamp-bandaid code that fails when `M2` fails after `M1`.         |
| **4** | **Code Reading Speed**           | Quickly understands `#retryer`, `#abortSignalConsumed`, and `observers` array in `query.ts`.                                                  | Breaks existing non-abortable query caching by cancelling queries that never read `context.signal`. |
| **5** | **Bug & Edge-Case Discovery**    | Tests `(M1 fail, M2 fail)`, `(M1 fail, M2 succeed)`, stale background fetch arriving mid-mutation, and 2->1->0 observers.                     | Only tests `(M1 succeed, M2 fail)` where naive snapshots happen to pass by luck!                    |
| **6** | **Testing Before Claiming Done** | Runs `pnpm --filter @tanstack/query-core test` after each step and writes deterministic fake-timer tests.                                     | Uses real `setTimeout` sleeps that flake or forgets to run the full `query-core` test suite.        |
| **7** | **Explaining Correctness**       | Clearly explains why operational transformation / delta-queue reduction over authoritative server state is required.                          | Cannot explain why `M2`'s snapshot is tainted by `M1`.                                              |

### Interviewer Probing Questions (Final 10 Minutes)

1. **Q**: _"Walk me through what happens with naive snapshot rollback if `M1 (+1)` starts at `t=0`, `M2 (+5)` starts at `t=10`, `M1` fails at `t=20`, and `M2` fails at `t=30`."_  
   **Expected Answer**: At `t=10`, `M2` captures `previous = 11` (which includes `M1`'s unconfirmed `+1`). At `t=20`, `M1` fails and sets cache to `10`. At `t=30`, `M2` fails and restores its captured `previous = 11`—leaving the cache at `11` even though _both_ mutations failed!

2. **Q**: _"Why must rollback recompute from remaining active updaters instead of restoring a snapshot?"_
   **Expected Answer**: Restoring a stale snapshot clobbers concurrent mutations that succeeded.
