# H04 — Polymorphic JSON `TypeAdapter` & Number Precision Trap

[⬅️ Back to Hard Catalog](README.md) · [🏠 Master Hub](../../../README.md)

| Attribute                    | Details                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| :--------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Case ID**                  | `H04`                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| **Difficulty Level**         | 🔴 **Hard** (`60–75 mins` — Senior / Staff Bar)                                                                                                                                                                                                                                                                                                                                                                                               |
| **Task Archetype**           | Bugfix + Cross-Module Contract                                                                                                                                                                                                                                                                                                                                                                                                                |
| **Source GitHub Repository** | [`google/gson`](https://github.com/google/gson)                                                                                                                                                                                                                                                                                                                                                                                               |
| **Target Files**             | `gson/src/main/java/com/google/gson/Gson.java`, `gson/src/main/java/com/google/gson/ToNumberPolicy.java`, `gson/src/main/java/com/google/gson/internal/bind/ObjectTypeAdapter.java`, `gson/src/main/java/com/google/gson/internal/bind/JsonTreeReader.java`, `extras/src/main/java/com/google/gson/typeadapters/RuntimeTypeAdapterFactory.java`, `gson/src/test/java/com/google/gson/functional/RuntimeTypeAdapterFactoryFunctionalTest.java` |
| **Supported Languages**      | `Java`                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| **Hard Taxonomy Pillars**    | Pillar 1 (Deceptive Abstraction) · Pillar 3 (Conflicting Type Contracts) · Pillar 4 (Concurrent Cache Initialization)                                                                                                                                                                                                                                                                                                                         |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Source Repository & Pull Request (Confidential)

| Field                              | Value                                      |
| :--------------------------------- | :----------------------------------------- |
| **Repository**                     | `https://github.com/google/gson`           |
| **Base SHA (pre-merge)**           | `b3f4ca20087f9066de4c340522ff84e0558e1ad1` |
| **Merge SHA (reference solution)** | `698ba9ebfdbf629ca4ccc393d9cecd69c1e7115f` |
| **Test Command**                   | `mvn test`                                 |

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/google/gson.git interview-workspace
cd interview-workspace
git checkout b3f4ca20087f9066de4c340522ff84e0558e1ad1
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
mvn test
```

### Reproducibility Verification

- **Base SHA (`b3f4ca20087f`)**: the test suite must contain at least one failing test related to the issue.
- **Merge SHA (`698ba9ebfdbf`)**: the same tests must pass after checkout.

### Files Changed (Reference Solution)

- gson/src/main/java/com/google/gson/internal/bind/TypeAdapterRuntimeTypeWrapper.java

### Failing Tests to Enable

- Failing tests to enable/verify: MoreSpecificTypeSerializationTest.java. Run the test command to confirm red on Base SHA and green on Merge SHA.

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Bug Report: Polymorphic Adapter Runtime Type Resolution
>
> Serialization uses declared rather than runtime types for wildcard/generic elements, producing incorrect output.
>
> ### Requirements
>
> - Use runtime types for wildcard element serialization.
> - Handle large integer values without precision loss.
> - Reject malformed surrogate pairs in strict mode.
>
> ### Acceptance Criteria
>
> 1. Trace the type adapter wrapper.
> 2. Fix runtime type resolution and edge cases.
> 3. Verify with polymorphic and numeric edge cases.

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Trusting the first plausible fix

- **What Naive AI Writes**: A minimal edit that makes the happy path pass but ignores the edge cases exercised by the real PR (`Use the runtime type for a wildcard element type`).
- **Why It Fails**: The PR touches `gson/.../TypeAdapterRuntimeTypeWrapper.java`; a shallow change leaves the underlying defect (ordering, caching, type resolution, or retry semantics) in place, so hidden tests still fail.
- **Correct Fix**: Reproduce the failing tests on Base SHA, then implement the same behavior change as the merged PR (study its diff), including edge cases and invariants.

### Trap 2: Over-editing unrelated code

- **What Naive AI Writes**: Refactors surrounding modules "while at it", changing public APIs.
- **Why It Fails**: Breaks callers and the hidden regression tests; the reference solution is minimal and scoped to the PR's changed lines.
- **Correct Fix**: Limit edits to the files/lines indicated by the failing tests; keep diffs small and behavior-focused.

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Trace the current behavior in `gson/.../TypeAdapterRuntimeTypeWrapper.java, MoreSpecificTypeSerializationTest.java` and identify why the failing tests fail on Base SHA."_
2. **Step 2 (`Plan`)**:
   - Reproduce with the test command; list the minimal files to change.
3. **Step 3 (`Prompt`)**:
   - Prompt 1: Implement the fix matching the merged PR's behavior, scoped to the failing tests.
   - Prompt 2: Add/adjust tests for edge cases (empty input, boundary values, error paths).
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Run the full test command; confirm all previously-failing tests pass and no regressions.

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

|   #   | Criterion                        | Strong Hire / Hire (`Score 3–4`)                                                                                                                     | No Hire / Blind Vibe-Coder (`Score 1–2`)                                                                    |
| :---: | :------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------- |
| **1** | **Problem Decomposition**        | Traces the 3 bugs separately and understands the boundary between `JsonReader` streaming and `JsonElement` tree buffering.                           | Tries to rewrite `ObjectTypeAdapter` from scratch instead of tracing `ToNumberPolicy` and `JsonTreeReader`. |
| **2** | **Prompt Context Quality**       | Mentions IEEE-754 53-bit mantissa limit (`2^53 + 1`) and `LazilyParsedNumber` when prompting AI.                                                     | Prompts _"Fix the number bug in ObjectTypeAdapter"_ without giving the `JsonTreeReader` context.            |
| **3** | **Not Blindly Trusting AI**      | Rejects any AI snippet that converts `String -> double -> long` or deletes the conflicting field validation completely.                              | Accepts `(long) in.nextDouble()` and wonders why `9007199254740993L` becomes `...992L`.                     |
| **4** | **Code Reading Speed**           | Quickly navigates `Gson.getAdapter`, `FutureTypeAdapter`, `Streams.parse`, and `ToNumberPolicy`.                                                     | Spends 25 minutes reading unrelated reflection code in `ReflectiveTypeAdapterFactory`.                      |
| **5** | **Bug & Edge-Case Discovery**    | Tests `2^53 + 1`, `Long.MAX_VALUE`, `1e308`, `NaN`/`Infinity` handling, and concurrent cyclic type lookup.                                           | Only tests small integers (`123`) that fit inside `double` without precision loss.                          |
| **6** | **Testing Before Claiming Done** | Runs `mvn test` after each change and adds explicit JUnit assertions for `assertEquals(9007199254740993L, map.get("txId"))`.                         | Claims done as soon as code compiles (`mvn test-compile`) without running JUnit.                            |
| **7** | **Explaining Correctness**       | Explains IEEE-754 `double` precision (`53` bits vs `64` bits) and why `threadLocalAdapterResults` only flushes to `typeTokenCache` at the root call. | Cannot explain why `9007199254740992L` passed while `9007199254740993L` failed.                             |

### Interviewer Probing Questions (Final 10 Minutes)

1. **Q**: _"Why did `9007199254740992L` (`2^53`) pass even when routed through `double`, whereas `9007199254740993L` (`2^53 + 1`) failed?"_  
   **Expected Answer**: `2^53` is an exact power of 2 (`1.0 * 2^53`), so its mantissa is all zeros and it is representable exactly in IEEE-754 `double`. `2^53 + 1` requires 54 bits of mantissa precision, so the least significant bit is rounded to even (`2^53`).
2. **Q**: _"Why can't `Gson.getAdapter()` put `FutureTypeAdapter` directly into the shared `ConcurrentHashMap` (`typeTokenCache`) before `factory.create()` returns?"_  
   **Expected Answer**: `FutureTypeAdapter` has a `null` delegate until `factory.create()` completes. Putting it in the thread-local map resolves cycles on the _current_ thread, while waiting until the outer call finishes before writing to `typeTokenCache` guarantees other threads only ever see fully initialized adapters.
