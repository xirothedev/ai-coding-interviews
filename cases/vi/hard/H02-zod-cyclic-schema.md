# H02 — Recursive Schema Validation & Cyclic Object Graph Tracker

[⬅️ Back to Hard Catalog](README.md) · [🏠 Master Hub](../../../README.md)

| Attribute                    | Details                                                                                                                                                                                                                                                                                                                            |
| :--------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Case ID**                  | `H02`                                                                                                                                                                                                                                                                                                                              |
| **Difficulty Level**         | 🔴 **Hard** (`60–75 mins` — Senior / Staff Bar)                                                                                                                                                                                                                                                                                    |
| **Task Archetype**           | Scale Optimization + State Mutation Bugfix                                                                                                                                                                                                                                                                                         |
| **Source GitHub Repository** | [`colinhacks/zod`](https://github.com/colinhacks/zod)                                                                                                                                                                                                                                                                              |
| **Target Files**             | **v3 Tag (`v3.23.8`)**: `src/types.ts`, `src/helpers/parseUtil.ts`, `src/__tests__/recursive.test.ts`, `src/__tests__/unions.test.ts` · **`main` Monorepo**: `packages/zod/src/v3/types.ts`, `packages/zod/src/v3/helpers/parseUtil.ts`, `packages/zod/src/v3/tests/recursive.test.ts`, `packages/zod/src/v3/tests/unions.test.ts` |
| **Supported Languages**      | `TypeScript`                                                                                                                                                                                                                                                                                                                       |
| **Hard Taxonomy Pillars**    | Pillar 1 (Shared Context Mutation) · Pillar 2 (Toy vs. Prod Scale) · Pillar 3 (DAG vs. Cycle Invariants)                                                                                                                                                                                                                           |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Source Repository & Pull Request (Confidential)

| Field                              | Value                                      |
| :--------------------------------- | :----------------------------------------- |
| **Repository**                     | `https://github.com/colinhacks/zod`        |
| **Base SHA (pre-merge)**           | `c5b9bcb39b7953c6a984849c6527863acdae0af7` |
| **Merge SHA (reference solution)** | `36f17960d1defca5d0896d9424f4e1059fbbf081` |
| **Test Command**                   | `pnpm test`                                |

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/colinhacks/zod.git interview-workspace
cd interview-workspace
git checkout c5b9bcb39b7953c6a984849c6527863acdae0af7
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
pnpm test
```

### Reproducibility Verification

- **Base SHA (`c5b9bcb39b79`)**: the test suite must contain at least one failing test related to the issue.
- **Merge SHA (`36f17960d1de`)**: the same tests must pass after checkout.

### Files Changed (Reference Solution)

- packages/zod/src/v4/core/memoizer.ts

### Failing Tests to Enable

- Failing tests to enable/verify: cyclic-data.test.ts. Run the test command to confirm red on Base SHA and green on Merge SHA.

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Bug Report: Async Validation Path Corruption & Cyclic Graph Handling
>
> Users validating complex nested data structures and recursive schemas have reported two critical issues in our schema validation library:
>
> 1. **Corrupted Error Paths During Async Validation**: When validating nested objects or unions asynchronously, validation errors intermittently report mutated or wrong issue paths when multiple async branches or properties resolve concurrently.
> 2. **Stack Overflow on Cyclic Object Graphs**: When validating recursive schemas against runtime objects that contain circular references, validation crashes the process instead of failing cleanly.
>
> ### Requirements
>
> - Async validation must report correct, isolated error paths even under concurrent resolution.
> - Recursive schemas must detect true cycles (an object appearing within its own descendant chain) and fail validation cleanly with a custom issue at the offending path, rather than throwing a stack overflow.
> - Shared non-cyclic references (the same instance referenced by sibling branches) must remain valid in both synchronous and asynchronous modes.
> - Deep or wide valid object graphs must complete without excessive time or memory growth.
>
> ### Acceptance Criteria
>
> 1. Trace how parse context paths are constructed and propagated across sync and async parsers; re-enable any disabled recursive/union regression tests.
> 2. Fix the async path mutation so concurrent validations report exact paths.
> 3. Implement cycle detection for recursive schemas that rejects ancestor cycles while allowing shared references in both sync and async execution.
> 4. Verify deep/wide valid graphs complete within reasonable time without leaks.

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Trusting the first plausible fix

- **What Naive AI Writes**: A minimal edit that makes the happy path pass but ignores the edge cases exercised by the real PR (`stop the memoizer from pinning a finished parse`).
- **Why It Fails**: The PR touches `packages/zod/src/v4/core/memoizer.ts`; a shallow change leaves the underlying defect (ordering, caching, type resolution, or retry semantics) in place, so hidden tests still fail.
- **Correct Fix**: Reproduce the failing tests on Base SHA, then implement the same behavior change as the merged PR (study its diff), including edge cases and invariants.

### Trap 2: Over-editing unrelated code

- **What Naive AI Writes**: Refactors surrounding modules "while at it", changing public APIs.
- **Why It Fails**: Breaks callers and the hidden regression tests; the reference solution is minimal and scoped to the PR's changed lines.
- **Correct Fix**: Limit edits to the files/lines indicated by the failing tests; keep diffs small and behavior-focused.

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Trace the current behavior in `packages/zod/src/v4/core/memoizer.ts, cyclic-data.test.ts` and identify why the failing tests fail on Base SHA."_
2. **Step 2 (`Plan`)**:
   - Reproduce with the test command; list the minimal files to change.
3. **Step 3 (`Prompt`)**:
   - Prompt 1: Implement the fix matching the merged PR's behavior, scoped to the failing tests.
   - Prompt 2: Add/adjust tests for edge cases (empty input, boundary values, error paths).
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Run the full test command; confirm all previously-failing tests pass and no regressions.

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

|   #   | Criterion                        | Strong Hire / Hire (`Score 3–4`)                                                                                                    | No Hire / Blind Vibe-Coder (`Score 1–2`)                                                                |
| :---: | :------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------ |
| **1** | **Problem Decomposition**        | Clearly separates path isolation in `ParseContext` from DFS ancestor tracking in `ZodLazy`.                                         | Dumps the whole prompt into AI, resulting in invasive changes across 15 schema classes.                 |
| **2** | **Prompt Context Quality**       | Explicitly instructs AI to distinguish **DFS ancestor cycles** from **DAG shared references** and handle `isAsync(result)`.         | Asks AI _"Add circular reference detection to ZodLazy"_, triggering the global `WeakSet` bug.           |
| **3** | **Not Blindly Trusting AI**      | Spots the `try ... finally` async Promise bug and the `WeakSet` DAG bug during diff review.                                         | Commits the `try ... finally` block without realizing `finally` runs before a returned Promise settles. |
| **4** | **Code Reading Speed**           | Understands `ZodType._parse`, `ParseInputLazyPath`, and `isAsync()` within 10 minutes.                                              | Gets lost in TypeScript generics instead of focusing on runtime `_parse` execution in `src/types.ts`.   |
| **5** | **Bug & Edge-Case Discovery**    | Tests shared sibling references (`{ a: shared, b: shared }`), self-cycles (`a.self = a`), and async refinements (`safeParseAsync`). | Only tests a 1-node sync cycle (`a.a = a`) and misses DAG siblings and `safeParseAsync`.                |
| **6** | **Testing Before Claiming Done** | Runs Vitest/Jest suite after every change and adds benchmark/regression tests in `recursive.test.ts`.                               | Claims done after only running 1 test manually.                                                         |
| **7** | **Explaining Correctness**       | Explains three-color DFS (white/gray/black) vs. global visited set and why per-branch ancestor scoping works in `Promise.all`.      | Cannot explain why `{ left: leaf, right: leaf }` failed in their first attempt.                         |

### Interviewer Probing Questions (Final 10 Minutes)

1. **Q**: _"Why does a single shared `Set` with `add` on entry and `delete` on exit fail when `safeParseAsync` validates two sibling branches concurrently via `Promise.all`?"_  
   **Expected Answer**: If `left` and `right` share the same `leaf` object and run concurrently via `Promise.all([parse(left), parse(right)])`, both branches enter `leaf` at the same time. If they share a single mutable `ancestors` Set, `right` sees `leaf` already in `ancestors` (added by `left` 1ms ago) and falsely reports a cycle! Each branch needs its own ancestor set along its parent chain.

2. **Q**: _"Why must a shared DAG sibling pass while a true ancestor cycle fails?"_
   **Expected Answer**: A DAG has no active ancestor on the stack; only re-entering an ancestor is a cycle.
