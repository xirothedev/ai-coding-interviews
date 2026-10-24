# M02 — Legacy Service Refactoring & Dependency Inversion

[⬅️ Back to Medium Catalog](README.md) · [🏠 Master Hub](../../../README.md)

| Attribute                    | Details                                                                                                                                                                                                                                                                 |
| :--------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Case ID**                  | `M02`                                                                                                                                                                                                                                                                   |
| **Difficulty Level**         | 🟡 **Medium** (`45–60 mins` — Standard SWE Bar)                                                                                                                                                                                                                         |
| **Task Archetype**           | Legacy Monolith-to-Library Extraction, Dependency Inversion & Atomic Batch Execution                                                                                                                                                                                    |
| **Source GitHub Repository** | [`JLLeitschuh/refactoring-interview-question`](https://github.com/JLLeitschuh/refactoring-interview-question)                                                                                                                                                           |
| **Target Files**             | `monolith/.../AlgorithmEngine.java`, `monolith/.../Algorithm.java`, `monolith/.../Dijkstra.java`, `library/.../Algorithm.java`, `library/.../Dijkstra.java`, `library/.../AlgorithmTest.java`, `library/.../DijkstraTest.java`, `monolith/.../AlgorithmEngineTest.java` |
| **Supported Languages**      | `Java`, `Kotlin`                                                                                                                                                                                                                                                        |
| **Primary AI Traps**         | Breaking `monolith`'s `AlgorithmEngine` / `AlgorithmEngineTest` signatures · Shared mutable `private Node source` in `Dijkstra` · Redundant `graphService.getByUuid(uuid)` N+1 query · Non-atomic `runForAll(true)` partial writes to `PathsService`                    |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Source Repository & Pull Request (Confidential)

| Field                              | Value                                                           |
| :--------------------------------- | :-------------------------------------------------------------- |
| **Repository**                     | `https://github.com/JLLeitschuh/refactoring-interview-question` |
| **Base SHA (pre-merge)**           | `c519ac981cdf744c6d3afa5551a00c18b9462183`                      |
| **Merge SHA (reference solution)** | `56150ed77832eb66fce658c8be37defbd160b2d1`                      |
| **Test Command**                   | `./gradlew test`                                                |

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/JLLeitschuh/refactoring-interview-question.git interview-workspace
cd interview-workspace
git checkout c519ac981cdf744c6d3afa5551a00c18b9462183
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
./gradlew test
```

### Reproducibility Verification

- **Base SHA (`c519ac981cdf`)**: the test suite must contain at least one failing test related to the issue.
- **Merge SHA (`56150ed77832`)**: the same tests must pass after checkout.

### Files Changed (Reference Solution)

- library/src/test/java/org/company/library/algorithm/AlgorithmTest.java

### Failing Tests to Enable

- Failing tests to enable/verify: AlgorithmTest.java, DijkstraTest.java. Run the test command to confirm red on Base SHA and green on Merge SHA.

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
>
> You are working on extracting our core graph shortest-path calculation engine (`Dijkstra` and `Algorithm`) out of a legacy database-coupled `:monolith` module into a clean, reusable `:library` module. You may use the AI Assistant freely.
>
> ### What We Need You to Do
>
> 1. **Decouple `Dijkstra` & Re-enable its Unit Tests (`:library`)**:
>    - Right now, `Dijkstra` is coupled to database-backed `GraphService` calls and holds mutable instance state (`source` node), making it stateful across runs and impossible to test without a live database.
>    - Refactor `Dijkstra` into a pure, stateless/thread-safe shortest-path calculator operating on domain `Graph` / `Node` / `Edge` objects, remove `@Disabled` from the `Dijkstra` unit test suite in `:library`, and make sure all directed and undirected graph tests pass.
> 2. **Extract `Algorithm` into `:library` via Dependency Inversion & Eliminate the N+1 Query**:
>    - Refactor `Algorithm` in `:library` using clean interfaces or seams so `:library` has zero compile-time dependencies on `:monolith`'s `GraphService`, `PathsService`, `EventService`, or `GraphUsersService`.
>    - Eliminate the redundant `N+1` lookup where `runForAll()` fetches all graphs and then re-queries each graph by UUID one by one.
>    - **Strict Backward Compatibility**: Keep `:monolith`'s `AlgorithmEngine` public API and its existing `:monolith` test suite 100% passing without modification.
> 3. **Re-enable the `:library` `Algorithm` Test Suite**:
>    - Remove `@Disabled` from the `Algorithm` unit test suite in `:library` and ensure all path calculation and event notification tests pass.
> 4. **Add Atomic Batch Execution (`runForAll(boolean failFast)`)**:
>    - Add an overloaded `runForAll(boolean failFast)` method (while preserving zero-arg `runForAll()`):
>      - When `failFast = true`: compute shortest paths for all graphs in the batch **before** persisting any path to storage. If any graph in the batch is invalid/corrupted or throws an exception, abort immediately so **zero partial writes** are persisted.
>      - When `failFast = false`: persist paths for valid graphs and emit failure events for invalid graphs without aborting the batch.

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Trusting the first plausible fix

- **What Naive AI Writes**: A minimal edit that makes the happy path pass but ignores the edge cases exercised by the real PR (`Point candidates at tests with obvious TODOs`).
- **Why It Fails**: The PR touches `the changed source files`; a shallow change leaves the underlying defect (ordering, caching, type resolution, or retry semantics) in place, so hidden tests still fail.
- **Correct Fix**: Reproduce the failing tests on Base SHA, then implement the same behavior change as the merged PR (study its diff), including edge cases and invariants.

### Trap 2: Over-editing unrelated code

- **What Naive AI Writes**: Refactors surrounding modules "while at it", changing public APIs.
- **Why It Fails**: Breaks callers and the hidden regression tests; the reference solution is minimal and scoped to the PR's changed lines.
- **Correct Fix**: Limit edits to the files/lines indicated by the failing tests; keep diffs small and behavior-focused.

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Trace the current behavior in `AlgorithmTest.java, DijkstraTest.java` and identify why the failing tests fail on Base SHA."_
2. **Step 2 (`Plan`)**:
   - Reproduce with the test command; list the minimal files to change.
3. **Step 3 (`Prompt`)**:
   - Prompt 1: Implement the fix matching the merged PR's behavior, scoped to the failing tests.
   - Prompt 2: Add/adjust tests for edge cases (empty input, boundary values, error paths).
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Run the full test command; confirm all previously-failing tests pass and no regressions.

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

|   #   | Criterion                        | Strong Hire / Hire (`Score 3–4`)                                                                                                       | No Hire / Blind Vibe-Coder (`Score 1–2`)                                                            |
| :---: | :------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------- |
| **1** | **Problem Decomposition**        | Tackles `Dijkstra` + `DijkstraTest` first, then `Algorithm` + `AlgorithmTest` + `AlgorithmEngine`, and finally `runForAll(failFast)`.  | Lets AI rewrite both `:monolith` and `:library` in one giant uncompileable diff.                    |
| **2** | **Prompt Context Quality**       | Explicitly specifies preserving `AlgorithmEngineTest` compatibility and staging computed paths before calling `saveNew` on `failFast`. | Prompts _"Refactor this repo and enable the disabled tests"_.                                       |
| **3** | **Not Blindly Trusting AI**      | Catches the partial-write bug in `runForAll(true)` (calling `saveNew` inside the computation loop before all graphs succeed).          | Commits AI code that persists graphs `0..i-1` to `PathsService` before throwing on graph `i`.       |
| **4** | **Code Reading Speed**           | Spots the redundant `graphService.getByUuid(uuid)` N+1 call and `private Node source` state in `Dijkstra` within 5–8 minutes.          | Misses the N+1 lookup in `runForAll()` or leaves `Dijkstra` stateful.                               |
| **5** | **Bug & Edge-Case Discovery**    | Tests failure on the _last_ graph of a `runForAll(true)` batch, cyclic/disconnected graphs in `DijkstraTest`, and empty graph lists.   | Only tests `runForAll(true)` when the _first_ graph fails (hiding the partial-write bug!).          |
| **6** | **Testing Before Claiming Done** | Un-disables both `DijkstraTest` and `AlgorithmTest`, keeps `AlgorithmEngineTest` green, and runs `./gradlew test`.                     | Leaves `@Disabled` on `AlgorithmTest` or breaks `:monolith:test`.                                   |
| **7** | **Explaining Correctness**       | Explains Dependency Inversion (Hexagonal / Ports & Adapters architecture) and two-phase batch validation/staging.                      | Cannot explain how `:library` stays independent of `:monolith` while `AlgorithmEngine` still works. |

### Interviewer Probing Questions (Final 10 Minutes)

1. **Q**: _"If a batch has 5 graphs and graph #4 throws an exception when `failFast = true`, how many paths have been written to `PathsService` in your implementation?"_  
   **Expected Answer**: `0` paths. Because `runForAll(true)` computes and stages all shortest paths in memory before invoking `PathsService.saveNew(...)`, graphs #1–#3 are never partially persisted.

2. **Q**: _"Why is a mutable `source` field on `Dijkstra` a correctness hazard?"_
   **Expected Answer**: It leaks state across calls and makes results depend on call order.
