# H06 — Model Validator Inheritance MRO & Default Factory Mutation Leak

[⬅️ Back to Hard Catalog](README.md) · [🏠 Master Hub](../../README.md)

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

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/pydantic/pydantic.git pydantic-interview
cd pydantic-interview
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
pytest tests/test_validators.py
```

### Seeded Defects to Inject Before the Session

1. **Bug 1 (Validator Override & Diamond MRO Bug in `_decorators.py`)**: In `DecoratorInfos.build(model_dc)`, iterate `model_dc.__mro__` in an order or dictionary-keying scheme where overriding a `@model_validator(mode='after')` method in a child class with the **same method name** either runs _both_ parent and child validators or reverses the execution order between `mode='before'` and `mode='after'`.
2. **Bug 2 (Shallow Mutation Leak in `BaseModel.model_copy`)**: In `pydantic/main.py` (`model_copy`), when `update={...}` is provided alongside nested mutable default containers (`list`, `dict`, `set`) or `__pydantic_extra__`, mutating a list on the copied instance mutates the original instance unless isolated.

---

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

### Trap 1: Reversing `reversed(model_dc.__mro__)` Globally (Whack-a-Mole Between `before` and `after`)

- **What Naive AI Writes**:
  - When `test_model_validator_after_mro_order` fails, the candidate pastes the failure into AI. The AI changes `for base in reversed(model_dc.__mro__):` to `for base in model_dc.__mro__:`.
- **Why It Fails**: Changing the traversal direction fixes `mode='after'` (or `mode='before'`) while **breaking the opposite mode** and breaking same-name method overrides!
- **Correct Fix**: Collect decorators walking `reversed(model_dc.__mro__)` into an insertion-ordered `dict[str, Decorator]` keyed by function/attribute name. Because Python `dict` preserves the key's _first_ insertion position (or can be moved to the end on override depending on desired MRO semantics) while overwriting the value with the most-derived class's implementation, overrides replace base methods cleanly! Furthermore, if a subclass overrides a decorated parent method with a plain undecorated method of the same name, check `base.__dict__` so the parent's stale validator is removed or rebound properly.

### Trap 2: Blanket `copy.deepcopy()` Breaking `threading.Lock` and Performance

- **What Naive AI Writes**:
  ```python
  # Inside model_copy:
  copied = copy.deepcopy(self)
  ```
- **Why It Fails**:
  1. `copy.deepcopy` on a model holding a `threading.Lock` or `asyncio.Event` raises `TypeError: cannot pickle '_thread.lock' object`.
  2. It slows down `model_copy` by `15x–30x`.
- **Correct Fix**: Shallow-copy `__dict__`, `__pydantic_fields_set__`, and `__pydantic_extra__` / `__pydantic_private__` (and shallow-clone top-level built-in mutable collections `list`, `dict`, `set` in `__dict__` when requested without invoking recursive `deepcopy` on arbitrary objects unless `deep=True`).

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Trace `DecoratorInfos.build` in `pydantic/_internal/_decorators.py` and explain how `model_validators` and `field_validators` are ordered and passed to `pydantic-core` schema generation for `mode='before'` vs `mode='after'`."_
2. **Step 2 (`Plan`)**:
   - Candidate verifies how `pydantic-core` wraps `before` validators (outer-to-inner) vs `after` validators (inner-to-outer).
3. **Step 3 (`Prompt`)**:
   - Prompt 1: Update `DecoratorInfos.build` to handle same-name overrides and `before`/`after` ordering.
   - Prompt 2: Update `model_copy` container isolation in `pydantic/main.py` without calling `copy.deepcopy` when `deep=False`.
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Run `pytest tests/test_validators.py` and test `arbitrary_types_allowed=True` with `threading.Lock()`.

---

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
