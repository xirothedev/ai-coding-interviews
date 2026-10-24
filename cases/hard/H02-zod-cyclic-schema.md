# H02 — Recursive Schema Validation & Cyclic Object Graph Tracker

[⬅️ Back to Hard Catalog](README.md) · [🏠 Master Hub](../../README.md)

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

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/colinhacks/zod.git zod-interview
cd zod-interview
# Option A: Pin v3 standalone layout (src/types.ts, src/helpers/parseUtil.ts, src/__tests__/*.test.ts)
git checkout v3.23.8
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
npm install && npm test

# Option B: Use main monorepo layout (packages/zod/src/v3/types.ts, packages/zod/src/v3/helpers/parseUtil.ts, packages/zod/src/v3/tests/*.test.ts)
# pnpm install && pnpm test
```

### Seeded Defects to Inject Before the Session

1. **Bug 1 (Mutable `path` Array in `ParseContext`)**: In `src/helpers/parseUtil.ts` (or `packages/zod/src/v3/helpers/parseUtil.ts` on `main`) or `ZodUnion._parse`, pass a shared mutable `ctx.path` array into child schemas (`path.push(key)` / `path.pop()`) so that when `parseAsync` runs union branches or object keys via `Promise.all()`, interleaved async resolutions corrupt the reported `issue.path`!
2. **Bug 2 (Unbounded Stack Overflow on Cyclic Objects in `ZodLazy`)**: `z.lazy(() => CategorySchema)` enters infinite recursion (`RangeError: Maximum call stack size exceeded`) when given a runtime object with a circular reference (`node.parent = node`).
3. **Commented Tests**: Comment out the async union path isolation test and cyclic graph tests in `src/__tests__/recursive.test.ts` and `src/__tests__/unions.test.ts` (or `packages/zod/src/v3/tests/recursive.test.ts` and `packages/zod/src/v3/tests/unions.test.ts` on `main`).

---

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
>
> You are working on `zod`, a TypeScript-first schema validation library. You have full access to the AI Assistant. We are evaluating how you analyze existing abstractions, avoid subtle graph/concurrency bugs, and optimize performance.
>
> ### Problem Context
>
> 1. **Async Path Corruption Bug**: When validating objects or unions asynchronously (`await schema.safeParseAsync(data)`), validation errors intermittently report the wrong `issue.path` (e.g., `["users", 0, "age", "name"]` instead of `["users", 0, "name"]`).
> 2. **Cycle Detection in `ZodLazy`**: When users validate cyclic object graphs (such as doubly-linked DOM/AST nodes or ORM entities where `user.posts[0].author === user`), `z.lazy()` crashes with `RangeError: Maximum call stack size exceeded`.
> 3. **Critical Distinction — Cycles vs. Shared DAG References**:
>    - A **Cycle** (an object appearing inside one of its own descendants: `a.child = a`) MUST be detected and fail validation cleanly with a `ZodIssueCode.custom` (`"Circular reference detected"` at the offending path) instead of throwing `RangeError`.
>    - A **Shared DAG Reference** (the same non-cyclic object referenced by two sibling fields, e.g., `const addr = { zip: "10001" }; const order = { billing: addr, shipping: addr }`) is **100% VALID** and MUST succeed!
>
> ### Examples
>
> ```ts
> const NodeSchema: z.ZodType<any> = z.lazy(() =>
>   z.object({ name: z.string(), next: NodeSchema.optional() }),
> );
>
> // Example 1: True Cycle -> Must return { success: false } with path: ["next", "next"]
> const a: any = { name: "A" };
> a.next = { name: "B", next: a };
> NodeSchema.safeParse(a); // -> { success: false, error: ZodError([ { message: "Circular reference detected", path: ["next", "next"] } ]) }
>
> // Example 2: Shared DAG Sibling -> Must return { success: true }!
> const leaf = { name: "Leaf" };
> const root = { left: leaf, right: leaf };
> const TreeSchema = z.object({ left: NodeSchema, right: NodeSchema });
> TreeSchema.safeParse(root); // -> { success: true, data: { left: { name: "Leaf" }, right: { name: "Leaf" } } }
> ```
>
> ### Your Tasks
>
> 1. **Explore & Trace**: Inspect `src/types.ts` (`ZodType`, `ZodObject`, `ZodUnion`, `ZodLazy`) and `src/helpers/parseUtil.ts`.
> 2. **Uncomment & Run Tests**: Run `npm test` and uncomment the disabled tests in `src/__tests__/recursive.test.ts` and `src/__tests__/unions.test.ts`.
> 3. **Fix Async Path Isolation & Implement Ancestor Cycle Detection**: Fix the `parseAsync` path corruption bug and add cycle detection to `ZodLazy` (or `ParseContext`) that rejects true cycles while permitting shared DAG references.
> 4. **Verify Performance & Edge Cases**: Ensure a 5,000-node deep/wide valid tree parses in `< 50ms` and handle `parseAsync` cycle cleanups properly when promises settle.

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Global `WeakSet` Rejecting Valid Shared DAG Siblings

- **What Naive AI Writes**:
  ```ts
  // Inside ParseContext or ZodLazy._parse:
  if (typeof input.data === "object" && input.data !== null) {
    if (ctx.common.seen.has(input.data)) {
      addIssueToContext(ctx, { code: ZodIssueCode.custom, message: "Circular reference detected" });
      return INVALID;
    }
    ctx.common.seen.add(input.data);
  }
  ```
- **Why It Fails**: `ctx.common.seen` is a global visited set across the entire parse run, NOT an active ancestor stack! In `const root = { left: leaf, right: leaf }`, parsing `root.left` adds `leaf` to `seen`. When the parser moves to sibling `root.right`, `seen.has(leaf)` is `true`—falsely rejecting a valid acyclic object!
- **Correct Fix**: Track the **active ancestor set** along the current recursion branch (DFS gray set):
  - For synchronous `_parse`: `ancestors.add(obj)` before recursing, and `ancestors.delete(obj)` in a `finally` block after returning!
  - For asynchronous `_parseAsync`: Either pass an immutable/cloned ancestor `Set` down child `ParseContext` frames (or remove `obj` inside `.finally()` after the child Promise resolves).

### Trap 2: Deleting from Shared `ancestors` Before Async Promise Resolves

- **What Naive AI Writes**:
  ```ts
  ancestors.add(data);
  try {
    return this._getter()._parse(input); // <-- Returns a Promise in async mode!
  } finally {
    ancestors.delete(data); // <-- Runs synchronously BEFORE the Promise resolves!
  }
  ```
- **Why It Fails**: In `parseAsync`, `this._getter()._parse(input)` returns a `Promise<SyncParseReturnType>`. The `finally` block executes immediately before the async branch descends into child properties, completely disabling cycle detection in async mode!
- **Correct Fix**: Check `isAsync(result)`: if synchronous, `ancestors.delete(data)` immediately; if async (`result instanceof Promise`), chain `result.finally(() => ancestors.delete(data))` (or scope `ancestors` per-path branch).

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Trace `ParseContext`, `ParseInput`, and `Lazy._parse` in `src/types.ts` and `src/helpers/parseUtil.ts`. Show how `ctx.path` is constructed and how sync vs async return types (`SyncParseReturnType` vs `AsyncParseReturnType`) work inside `_parse`."_
2. **Step 2 (`Plan`)**:
   - Candidate notes that `ZodLazy._parse` can return either a sync result or a `Promise`, and that DAG siblings require an **ancestor stack** rather than a global `WeakSet`.
3. **Step 3 (`Prompt`)**:
   - Prompt 1: Fix `ParseContext` path propagation in union/object async branches.
   - Prompt 2: Implement ancestor tracking in `ZodLazy._parse` handling both sync and `Promise` return values.
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Candidate checks whether `finally` runs prematurely on Promises and writes tests for both `safeParse` and `safeParseAsync` on cyclic and DAG inputs.

---

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
