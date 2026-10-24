# H04 — Polymorphic JSON `TypeAdapter` & Number Precision Trap

> 🌐 Language: **English** · <a href="vi/H04-gson-polymorphic-adapter">Tiếng Việt</a>

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

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/google/gson.git gson-interview
cd gson-interview
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
mvn test-compile
```

### Seeded Defects to Inject Before the Session

1. **Bug 1 (64-Bit Long Truncation in `JsonTreeReader` + `ObjectTypeAdapter`)**: When a polymorphic adapter buffers a JSON object into a `JsonElement` via `Streams.parse(in)` and delegates reading via `new JsonTreeReader(jsonElement)`, `ObjectTypeAdapter` (configured with `ToNumberPolicy.LONG_OR_DOUBLE`) calls `in.nextDouble()` or loses precision on 64-bit integers `> 2^53` (e.g., `9007199254740993L` becomes `9007199254740992L` or a `Double`!).
2. **Bug 2 (Duplicate Discriminator Key Crash on Serialization)**: In `RuntimeTypeAdapterFactory`, when `maintainType = true` AND the subtype class also defines a Java field mapped to the type field name (e.g., `String type = "credit_card"`), serializing throws `JsonParseException: cannot serialize ... because it already defines a field named type` instead of allowing consistent discriminator serialization.
3. **Bug 3 (`FutureTypeAdapter` Concurrent Cache Publication)**: In `Gson.getAdapter(TypeToken<T>)`, publishing the intermediate `FutureTypeAdapter` to `typeTokenCache` before `factory.create()` finishes causes concurrent threads to read an unresolved delegate.

---

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Production Incident Report: 64-Bit ID Precision Loss in Polymorphic JSON & Concurrent Adapter Lookup
>
> A payment processing service using our JSON library for polymorphic subtype deserialization (`RuntimeTypeAdapterFactory`) alongside dynamic `Map<String, Object>` metadata fields (configured with `LONG_OR_DOUBLE` number handling) is hitting three production defects:
>
> 1. **Silent 64-Bit Integer Precision Corruption (`> 2^53`)**:
>    - When `{"txId": 9007199254740993}` is deserialized directly into a `Map<String, Object>` from a raw JSON stream, `txId` is accurately parsed as `Long.valueOf(9007199254740993L)`.
>    - However, when that exact same `Map<String, Object>` sits inside a polymorphic parent object deserialized via `RuntimeTypeAdapterFactory` (which buffers the JSON into an in-memory element tree before delegating to the subtype adapter), `txId` is silently corrupted into `9007199254740992L` or a `Double` (`9.007199254740992E15`) because the buffered tree-reading path routes numbers through 64-bit IEEE-754 floating-point!
> 2. **Discriminator Field Collision When `maintainType = true`**:
>    - When `RuntimeTypeAdapterFactory` is configured with `maintainType = true` and a concrete subtype class also declares a Java field matching the discriminator key name (e.g., `final String type = "card"` matching the registered subtype label `"card"`), serialization throws `JsonParseException` ("already defines a field named type").
>    - Requirement: Serialization must succeed when the subtype field's value matches the registered label (or when `maintainType` is enabled with a consistent label), while **still** throwing `JsonParseException` if the POJO's field value contradicts the registered subtype label!
> 3. **Thread-Safe Adapter Resolution for Mutually Recursive Types**:
>    - When multiple threads concurrently request a `TypeAdapter` for mutually recursive classes (`NodeA <-> NodeB`) for the first time, an in-progress placeholder adapter can be published to the shared adapter cache before initialization completes, exposing an unresolved delegate to other threads.
>
> ### Acceptance Criteria
>
> 1. Search the codebase to trace how polymorphic deserialization buffers JSON into a tree, how tree-based readers and number policies parse numbers into `Object` maps, and how recursive `TypeAdapter` instances are cached. Uncomment any disabled regression tests in the test suite.
> 2. Fix the buffered tree number-reading path so 64-bit `Long` values (`9007199254740993L`, `Long.MAX_VALUE`, `Long.MIN_VALUE`) preserve full 64-bit integer precision under `LONG_OR_DOUBLE` while still falling back to `Double` for decimal or out-of-range floating-point numbers.
> 3. Fix `RuntimeTypeAdapterFactory` discriminator serialization so consistent subtype fields serialize cleanly without weakening validation against contradictory discriminator values.
> 4. Ensure concurrent `getAdapter` calls on cyclic type graphs are 100% thread-safe and never expose uninitialized proxy adapters to other threads, and verify all JUnit tests pass.

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Calling `JsonPrimitive.getAsDouble()` Inside `JsonTreeReader.nextString()` / `ObjectTypeAdapter`

- **What Naive AI Writes**:
  - In `ObjectTypeAdapter`, when token is `JsonToken.NUMBER`, AI sees `in instanceof JsonTreeReader` and calls `in.nextDouble()` and casts `(long) d` if `d == Math.rint(d)`!
- **Why It Fails**: Any IEEE-754 `double` only has 53 bits of significand precision (`MAX_SAFE_INTEGER = 9007199254740991`). Passing `9007199254740993L` through `double` rounds it to `9007199254740992.0`, which is an exact integer (`d == Math.rint(d)` is `true`!), so `(long) d` silently produces the **wrong 64-bit ID (`...992L`)**!
- **Correct Fix**: `JsonPrimitive` stores parsed JSON numbers lazily as `LazilyParsedNumber` (backed by the exact `String` representation from `Streams.parse`). `ToNumberPolicy.LONG_OR_DOUBLE.readNumber(in)` calls `in.nextString()`, then attempts `Long.parseLong(value)` _first_, falling back to `Double.valueOf(value)` only if `NumberFormatException` occurs! Ensure `JsonTreeReader.nextString()` returns `((JsonPrimitive) popStack()).getAsString()` without routing through `double`.

### Trap 2: Silencing the Duplicate Field Check in `RuntimeTypeAdapterFactory` Unconditionally

- **What Naive AI Writes**:
  - AI simply deletes the `if (jsonObject.has(typeFieldName))` check during serialization!
- **Why It Fails**: Deleting the check completely breaks the existing unit test `testSerializeCollidingTypeFieldWithDifferentValue`, where a POJO has `int type = 42` (or `String type = "wrong_label"`) that conflicts with the polymorphic discriminator!
- **Correct Fix**: Allow `jsonObject.has(typeFieldName)` _only_ when `maintainType` is enabled (or when the serialized value equals `new JsonPrimitive(label)`), and throw `JsonParseException` if it contradicts `label`.

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not modify code yet. Trace how `RuntimeTypeAdapterFactory` buffers a `JsonReader` into a `JsonElement` and passes it to `delegate.fromJsonTree(jsonElement)`. Specifically, show what `JsonTreeReader` and `ToNumberPolicy.LONG_OR_DOUBLE` do when reading a `NUMBER` token."_
2. **Step 2 (`Plan`)**:
   - Candidate isolates the 3 files (`JsonTreeReader.java` / `ToNumberPolicy.java`, `RuntimeTypeAdapterFactory.java`, and `Gson.java`).
3. **Step 3 (`Prompt`)**:
   - Prompt each fix independently, specifying that `9007199254740993L` must never pass through a 64-bit `double` conversion.
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Run `mvn test` on the targeted test classes and verify all boundary numbers (`Long.MAX_VALUE`, `Long.MIN_VALUE`, `9007199254740993L`, `3.14159`).

---

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
