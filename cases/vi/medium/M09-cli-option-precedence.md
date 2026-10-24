# M09 — CLI Subcommand Option Parser & Env-Var Fallback Precedence

[⬅️ Back to Medium Catalog](README.md) · [🏠 Master Hub](../../../README.md)

| Attribute                    | Details                                                                                                                             |
| :--------------------------- | :---------------------------------------------------------------------------------------------------------------------------------- |
| **Case ID**                  | `M09`                                                                                                                               |
| **Difficulty Level**         | 🟡 **Medium** (`45–60 mins` — Standard SWE Bar)                                                                                     |
| **Task Archetype**           | Bugfix + Feature Extension                                                                                                          |
| **Source GitHub Repository** | [`pallets/click`](https://github.com/pallets/click) (Python) · [`tj/commander.js`](https://github.com/tj/commander.js) (TypeScript) |
| **Target Files**             | `src/click/core.py`, `src/click/types.py`, `tests/test_options.py`, `tests/test_context.py`                                         |
| **Supported Languages**      | `Python`, `TypeScript`, `Go`, `Rust`                                                                                                |
| **Primary AI Traps**         | Falsy CLI value (`False`, `0`, `""`) falling through `cli_val or env_val or default` · Mutating `default_map` across subcommands    |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Source Repository & Pull Request (Confidential)

| Field                              | Value                                      |
| :--------------------------------- | :----------------------------------------- |
| **Repository**                     | `https://github.com/pallets/click`         |
| **Base SHA (pre-merge)**           | `08ecfd0e7c238a2444886d239de6d0e9d83530ec` |
| **Merge SHA (reference solution)** | `166b31261f55ba3126456bbc2ff9e16142115e56` |
| **Test Command**                   | `pytest`                                   |

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/pallets/click.git interview-workspace
cd interview-workspace
git checkout 08ecfd0e7c238a2444886d239de6d0e9d83530ec
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
pytest
```

### Reproducibility Verification

- **Base SHA (`08ecfd0e7c23`)**: the test suite must contain at least one failing test related to the issue.
- **Merge SHA (`166b31261f55`)**: the same tests must pass after checkout.

### Files Changed (Reference Solution)

- src/click/core.py

### Failing Tests to Enable

- Failing tests to enable/verify: test_options.py. Run the test command to confirm red on Base SHA and green on Merge SHA.

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Bug Report: CLI Option Precedence
>
> Option default resolution and precedence between context, option, and environment is incorrect.
>
> ### Requirements
>
> - Resolve precedence: explicit CLI flag > environment > config/default map > option default.
> - Handle boolean and empty-string options correctly.
> - Ensure option show_default respects context settings.
>
> ### Acceptance Criteria
>
> 1. Trace the core option resolution.
> 2. Fix precedence handling.
> 3. Verify with env vars, defaults, and flags.

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Trusting the first plausible fix

- **What Naive AI Writes**: A minimal edit that makes the happy path pass but ignores the edge cases exercised by the real PR (`Give Option.show_default higher priority wrt Context.show_default`).
- **Why It Fails**: The PR touches `src/click/core.py`; a shallow change leaves the underlying defect (ordering, caching, type resolution, or retry semantics) in place, so hidden tests still fail.
- **Correct Fix**: Reproduce the failing tests on Base SHA, then implement the same behavior change as the merged PR (study its diff), including edge cases and invariants.

### Trap 2: Over-editing unrelated code

- **What Naive AI Writes**: Refactors surrounding modules "while at it", changing public APIs.
- **Why It Fails**: Breaks callers and the hidden regression tests; the reference solution is minimal and scoped to the PR's changed lines.
- **Correct Fix**: Limit edits to the files/lines indicated by the failing tests; keep diffs small and behavior-focused.

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Trace the current behavior in `src/click/core.py, test_options.py` and identify why the failing tests fail on Base SHA."_
2. **Step 2 (`Plan`)**:
   - Reproduce with the test command; list the minimal files to change.
3. **Step 3 (`Prompt`)**:
   - Prompt 1: Implement the fix matching the merged PR's behavior, scoped to the failing tests.
   - Prompt 2: Add/adjust tests for edge cases (empty input, boundary values, error paths).
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Run the full test command; confirm all previously-failing tests pass and no regressions.

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

|   #   | Criterion                        | Strong Hire / Hire (`Score 3–4`)                                                                                                         | No Hire / Blind Vibe-Coder (`Score 1–2`)                                                                             |
| :---: | :------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------- |
| **1** | **Problem Decomposition**        | Separates the 4-tier lookup sentinel logic in `consume_value` from string-to-type conversion in `value_from_envvar` / `type_cast_value`. | Hacks special cases for `False` and `0` while leaving `""` and `[]` broken.                                          |
| **2** | **Prompt Context Quality**       | Specifies sentinel identity check (`is not UNSET`), `ParameterSource` tracking during lookup, and empty env string behavior.             | Prompts _"Fix falsy CLI values in `core.py`"_.                                                                       |
| **3** | **Not Blindly Trusting AI**      | Catches `"".split(",") == [""]` and `False == 0` in Python value comparisons when auditing AI diffs.                                     | Accepts `if val is not None:` without noticing `consume_value` uses `UNSET` (when `None` can be an explicit value!). |
| **4** | **Code Reading Speed**           | Traces `handle_parse_result -> consume_value -> process_value` in `src/click/core.py` within 8 minutes.                                  | Edits parser tokenizer (`parser.py`) instead of parameter consumption (`core.py`).                                   |
| **5** | **Bug & Edge-Case Discovery**    | Tests `--count 0` (when default is `0`), `--no-flag` with `ENV=1`, `ENV="0"` vs `ENV="false"`, and `ENV=""` on `multiple=True`.          | Misses the test where explicit CLI value equals the default value (`--count 0` with `default=0`).                    |
| **6** | **Testing Before Claiming Done** | Runs `pytest tests/test_options.py tests/test_context.py` after each edit.                                                               | Runs only 1 test and breaks existing `test_options.py` cases.                                                        |
| **7** | **Explaining Correctness**       | Explains why sentinel identity (`val is _UNSET`) is required over `None` or equality checks (`==`) in dynamic languages.                 | Cannot explain why `False == 0` in Python causes bugs when checking defaults in sets/dicts.                          |

### Interviewer Probing Questions (Final 10 Minutes)

1. **Q**: _"In Python, why is even `if value is not None:` sometimes insufficient as a sentinel check in a configuration parser?"_  
   **Expected Answer**: Because a user or `default_map` might explicitly pass `None` to unset/disable an optional setting! Using a private singleton sentinel `_UNSET = object()` and checking `if value is not _UNSET:` distinguishes "not provided" from an explicit `None`, `False`, `0`, or `""`.

2. **Q**: _"Why must CLI values be checked for presence rather than truthiness?"_
   **Expected Answer**: Falsy values like `0`, `False`, or `""` are valid inputs and must not fall through to env/default.
