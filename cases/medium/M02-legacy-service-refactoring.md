# M02 — Legacy Service Refactoring & Dependency Inversion

[⬅️ Back to Medium Catalog](README.md) · [🏠 Master Hub](../../README.md)

| Attribute                    | Details                                                                                                         |
| :--------------------------- | :-------------------------------------------------------------------------------------------------------------- |
| **Case ID**                  | `M02`                                                                                                           |
| **Difficulty Level**         | 🟡 **Medium** (`45–60 mins` — Standard SWE Bar)                                                                 |
| **Task Archetype**           | Legacy Refactoring & Performance Optimization                                                                   |
| **Source GitHub Repository** | [`JLLeitschuh/refactoring-interview-question`](https://github.com/JLLeitschuh/refactoring-interview-question)   |
| **Target Files**             | `src/main/java/...` & `src/test/java/...` _(or TypeScript / Python port)_                                       |
| **Supported Languages**      | `Java`, `TypeScript`, `Python`                                                                                  |
| **Primary AI Traps**         | Breaking public constructor/method signatures · Shared mutable static cache leaking state across parallel tests |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/JLLeitschuh/refactoring-interview-question.git refactoring-interview
cd refactoring-interview
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
./gradlew test
```

### Seeded Defects to Inject Before the Session

1. **Bug 1 (Static Mutable Cache / Singleton Leak)**: The legacy service stores processed records in a `private static final List/Map` that is never cleared between instances, causing test order dependency and concurrent race conditions when multiple service instances run in parallel.
2. **Bug 2 (Hardcoded External Dependency & Resource Leak)**: File/network stream readers are instantiated directly inside business logic without `try-with-resources` (or context manager), leaking file descriptors when a malformed record throws an exception mid-batch.

---

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
>
> You are working on a legacy backend service (`JLLeitschuh/refactoring-interview-question`). You may use the AI Assistant freely.
>
> ### Problem Context
>
> This service currently suffers from tight coupling, static state leakage, and poor error handling:
>
> 1. **State Isolation & Concurrency Bug**: Creating two separate service instances in the same JVM/process shares underlying mutable static state, causing data from Request A to leak into Request B and failing when tests run in parallel.
> 2. **Strict Backward-Compatible API Contract**: Existing callers in production instantiate this class using its current public constructor and method signatures. **You must NOT break existing public constructor or method signatures**, while introducing Dependency Injection (constructor overloading) so data sources/repositories can be mocked in unit tests.
> 3. **Batch Processing Mode (`processBatch`)**: Add a `BatchResult processBatch(List<Record> records, boolean failFast)` method:
>    - When `failFast = true`: if any record is invalid, abort immediately and roll back (commit `0` records to the repository).
>    - When `failFast = false`: commit all valid records, collect errors for invalid records with their index and reason, and return `BatchResult(succeededCount, failedRecords)`.
>
> ### Your Tasks
>
> 1. **Explore & Trace**: Inspect the source and test files. Run `./gradlew test` (or `pytest` / `npm test`).
> 2. **Uncomment & Run Failing Tests**: Uncomment the parallel isolation and resource-cleanup tests in the test suite.
> 3. **Refactor with Backward Compatibility**: Eliminate static state leakage, close resources safely on exception, and add constructor-injected dependencies while keeping the existing zero-arg/legacy constructor working.
> 4. **Implement `processBatch` & Verify**: Implement `processBatch` supporting both `failFast = true` (atomic rollback) and `failFast = false` (partial success) and add comprehensive unit tests.

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Breaking Public Constructor & Method Signatures

- **What Naive AI Writes**:
  - When prompted _"Refactor this class to use dependency injection and clean architecture"_, LLMs routinely replace the existing constructor `public LegacyService()` with `public LegacyService(Repository repo, Validator validator)` and rename methods—causing external caller tests to fail with compilation errors!
- **Correct Fix**: Keep `public LegacyService()` as a delegating constructor (`this(new DefaultRepository(), new DefaultValidator())`) that chains to the new injectable constructor!

### Trap 2: Non-Atomic `failFast = true` Partial Writes

- **What Naive AI Writes**:
  ```java
  for (Record r : records) {
      if (!isValid(r)) {
          if (failFast) throw new ValidationException(...);
      }
      repository.save(r); // <-- Already saved records 0..i-1 before record i failed!
  }
  ```
- **Why It Fails**: When `failFast = true` and record `#3` fails validation, records `#0`, `#1`, and `#2` were already written to `repository.save()`!
- **Correct Fix**: Validate all records (or stage transformed entities in a buffer) _before_ invoking `repository.saveAll()` when `failFast = true`.

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. List all public constructors and public methods of the service class that must remain backward-compatible, and identify every `static` field or unclosed I/O resource."_
2. **Step 2 (`Plan`)**:
   - Candidate plans constructor chaining (`LegacyService()` -> `LegacyService(deps)`), instance-scoped state, and two-phase validation before commit for `failFast = true`.
3. **Step 3 (`Prompt`)**:
   - Prompt 1: Refactor static state to instance fields and add overloaded constructor.
   - Prompt 2: Implement `processBatch` with pre-commit validation for `failFast = true`.
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Verify original unit tests pass unmodified alongside new `processBatch` and concurrency tests.

---

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

|   #   | Criterion                        | Strong Hire / Hire (`Score 3–4`)                                                                                                        | No Hire / Blind Vibe-Coder (`Score 1–2`)                                                     |
| :---: | :------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------- |
| **1** | **Problem Decomposition**        | Separates backward-compatible DI refactoring from `processBatch` feature implementation.                                                | Lets AI rewrite the entire package structure in one massive diff.                            |
| **2** | **Prompt Context Quality**       | Explicitly instructs AI to preserve existing public constructors via constructor chaining and enforce atomic `failFast`.                | Prompts _"Refactor this class and add `processBatch`"_.                                      |
| **3** | **Not Blindly Trusting AI**      | Catches the partial-write bug in `failFast = true` (saving records `0..i-1` before throwing on record `i`).                             | Commits AI code that leaves partial records in the repository when `failFast = true` throws. |
| **4** | **Code Reading Speed**           | Spots the `static` collection leak and unclosed resource stream within 5–8 minutes.                                                     | Misses the `static` keyword on the shared collection.                                        |
| **5** | **Bug & Edge-Case Discovery**    | Tests failure on the _last_ item of a `failFast = true` batch, empty batches, and concurrent instances.                                 | Only tests `failFast = true` when the _first_ item fails (hiding the partial-write bug!).    |
| **6** | **Testing Before Claiming Done** | Runs `./gradlew test` after each step and writes a test where item `#3` of `5` fails under `failFast = true`.                           | Claims done without testing mid-batch failure rollback.                                      |
| **7** | **Explaining Correctness**       | Explains Constructor Chaining / Seam pattern (Michael Feathers' _Working Effectively with Legacy Code_) and two-phase batch validation. | Cannot explain how to introduce DI without breaking legacy callers.                          |

### Interviewer Probing Questions (Final 10 Minutes)

1. **Q**: _"If a batch has 5 items and item #4 is invalid when `failFast = true`, what is the state of the repository in your implementation?"_  
   **Expected Answer**: `0` items saved. Because we validate/stage all items before persisting when `failFast = true`, items #1–#3 are never partially committed.
