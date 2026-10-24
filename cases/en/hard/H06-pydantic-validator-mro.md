# H06 — Model Validator Inheritance MRO & Default Factory Mutation Leak

[⬅️ Back to Hard Catalog](README.md) · [🏠 Master Hub](../../../README.md)

| Attribute                    | Details                                                                                                                          |
| :--------------------------- | :------------------------------------------------------------------------------------------------------------------------------- |
| **Case ID**                  | `H06`                                                                                                                            |
| **Difficulty Level**         | 🔴 **Hard** (`60–75 mins` — Senior / Staff Bar)                                                                                  |
| **Task Archetype**           | Deceptive Abstraction + Cross-Module Invariant Bugfix                                                                            |
| **Source GitHub Repository** | [`pydantic/pydantic`](https://github.com/pydantic/pydantic)                                                                      |
| **Target Files**             | `pydantic/_internal/_decorators.py`, `pydantic/_internal/_model_construction.py`, `pydantic/main.py`, `tests/test_validators.py` |
| **Supported Languages**      | `Python`                                                                                                                         |
| **Hard Taxonomy Pillars**    | Pillar 1 (Deceptive Metaclass Abstraction) · Pillar 2 (Performance Cliff) · Pillar 3 (Conflicting MRO Invariants)                |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Source Repository & Pull Request (Confidential)

| Field                              | Value                                      |
| :--------------------------------- | :----------------------------------------- |
| **Repository**                     | `https://github.com/pydantic/pydantic`     |
| **Base SHA (pre-merge)**           | `28e83965098c52536af2beb54dcd4da777a4fcd2` |
| **Merge SHA (reference solution)** | `a13a3cb12ebf31279129bc465d37548db06cb731` |
| **Test Command**                   | `pytest`                                   |

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/pydantic/pydantic.git interview-workspace
cd interview-workspace
git checkout 28e83965098c52536af2beb54dcd4da777a4fcd2
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
pytest
```

### Reproducibility Verification

- **Base SHA (`28e83965098c`)**: the test suite must contain at least one failing test related to the issue.
- **Merge SHA (`a13a3cb12ebf`)**: the same tests must pass after checkout.

### Files Changed (Reference Solution)

- pydantic/_internal/_decorators.py, pydantic/_internal/_generate_schema.py

### Failing Tests to Enable

- Failing tests to enable/verify: test_validators.py, test_json.py, test_serialize.py. Run the test command to confirm red on Base SHA and green on Merge SHA.

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
>
> You are working inside `pydantic`. You have full access to the AI Assistant and `pytest`. We are evaluating your ability to reason about Python's Method Resolution Order (MRO), metaclass schema construction, and performance-sensitive object copying.
>
> ### What We Need You to Do
>
> 1. **Validator Inheritance & Method Override Contract**:
>    - When `Child(Parent)` defines a `@model_validator` or `@field_validator` with the **exact same method name** as `Parent`, `Child`'s validator must **override (replace)** `Parent`'s validator of that name—not run both.
>    - Furthermore, if a subclass overrides a decorated parent validator method with a plain undecorated method of the same name, the parent's stale validator must not execute.
>    - When `Parent` and `Child` define validators with _different_ method names, execution order must respect mode semantics:
>      - `mode='after'` validators run **Base → Derived (`Parent` first, then `Child`)** so `Child` can rely on invariants established by `Parent`.
>      - `mode='before'` (and `mode='wrap'`) validators run **Derived → Base (`Child` first/outermost, then `Parent`)** so `Child` can pre-process raw inputs before `Parent`'s schema parses them.
> 2. **Safe Container Isolation in `model_copy(update=...)`**:
>    - Calling `b = a.model_copy(update={'name': 'new'})` and then mutating `b.tags` (where `tags: list[str] = []` or `Field(default_factory=list)`) or `b.__pydantic_extra__` currently mutates `a.tags` / `a.__pydantic_extra__` when `deep=False`.
>    - However, blindly running `copy.deepcopy(self)` when `deep=False` is **unacceptable**: models with `model_config = ConfigDict(arbitrary_types_allowed=True)` holding non-pickleable objects (e.g., `threading.Lock()`, sockets, or DB connections) must not crash on `model_copy()`, and copying 50,000 models must complete in `< 0.15s`.
>
> Please explore how decorator collection, metaclass schema construction, and `model_copy` work in the codebase, re-enable any commented-out validator/copy tests, fix both issues, and verify diamond inheritance and `threading.Lock` edge cases.

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Trusting the first plausible fix

- **What Naive AI Writes**: A minimal edit that makes the happy path pass but ignores the edge cases exercised by the real PR (`Fix root validators & subclasses`).
- **Why It Fails**: The PR touches `pydantic/_internal/_decorators.py, pydantic/_internal/_generate_schema.py`; a shallow change leaves the underlying defect (ordering, caching, type resolution, or retry semantics) in place, so hidden tests still fail.
- **Correct Fix**: Reproduce the failing tests on Base SHA, then implement the same behavior change as the merged PR (study its diff), including edge cases and invariants.

### Trap 2: Over-editing unrelated code

- **What Naive AI Writes**: Refactors surrounding modules "while at it", changing public APIs.
- **Why It Fails**: Breaks callers and the hidden regression tests; the reference solution is minimal and scoped to the PR's changed lines.
- **Correct Fix**: Limit edits to the files/lines indicated by the failing tests; keep diffs small and behavior-focused.

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Trace the current behavior in `pydantic/_internal/_decorators.py, pydantic/_internal/_generate_schema.py, test_validators.py, test_json.py, test_serialize.py` and identify why the failing tests fail on Base SHA."_
2. **Step 2 (`Plan`)**:
   - Reproduce with the test command; list the minimal files to change.
3. **Step 3 (`Prompt`)**:
   - Prompt 1: Implement the fix matching the merged PR's behavior, scoped to the failing tests.
   - Prompt 2: Add/adjust tests for edge cases (empty input, boundary values, error paths).
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Run the full test command; confirm all previously-failing tests pass and no regressions.

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

|   #   | Criterion                        | Strong Hire / Hire (`Score 3–4`)                                                                                                  | No Hire / Blind Vibe-Coder (`Score 1–2`)                                                                 |
| :---: | :------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------- |
| **1** | **Problem Decomposition**        | Analyzes `pydantic-core` wrapping order for `before` vs `after` before touching `_decorators.py`.                                 | Repeatedly flips `reversed(__mro__)` back and forth as tests fail.                                       |
| **2** | **Prompt Context Quality**       | Specifies both `mode='before'` (Derived → Base) and `mode='after'` (Base → Derived) plus `threading.Lock` constraints in prompts. | Prompts _"Fix MRO test in `test_validators.py`"_ with no explanation of why `before` and `after` differ. |
| **3** | **Not Blindly Trusting AI**      | Rejects AI's `copy.deepcopy()` suggestion on `deep=False`.                                                                        | Accepts `copy.deepcopy()` and fails the `threading.Lock` and benchmark tests.                            |
| **4** | **Code Reading Speed**           | Traces `_decorators.py` → `_generate_schema.py` quickly and understands how `DecoratorInfos` is cached on classes.                | Gets lost in C/Rust `pydantic-core` bindings instead of inspecting `_decorators.py`.                     |
| **5** | **Bug & Edge-Case Discovery**    | Tests diamond MRO, overriding a validator with a non-validator method, and `__pydantic_extra__` mutation.                         | Misses the case where `Child` overrides `Parent`'s validator method name.                                |
| **6** | **Testing Before Claiming Done** | Runs the full `test_validators.py` suite plus a `threading.Lock` + 50k copy micro-benchmark.                                      | Only runs the single failing test function in isolation.                                                 |
| **7** | **Explaining Correctness**       | Articulates why `mode='before'` wraps outside-in while `mode='after'` wraps inside-out around core validation.                    | Cannot explain why `Parent` must run before `Child` in `mode='after'`.                                   |

### Interviewer Probing Questions (Final 10 Minutes)

1. **Q**: _"From first principles, why should `mode='before'` validators run `Child → Parent`, while `mode='after'` validators run `Parent → Child`?"_  
   **Expected Answer**: Before core field parsing (`mode='before'`), the input is raw untyped data (e.g., a `dict`); `Child` may normalize new subclass-specific raw keys into the format `Parent` expects. After core validation (`mode='after'`), `self` is an initialized instance; `Parent`'s invariants must be verified first so `Child`'s `after` validator can safely assume `Parent` fields are valid.

2. **Q**: _"Why does reversing MRO globally break `mode='before'` validators?"_
   **Expected Answer**: `before` validators must run base-to-subclass; reversing them inverts the required order.
