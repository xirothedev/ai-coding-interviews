# M07 — Markdown Table & Footnote AST Tokenizer

[⬅️ Back to Medium Catalog](README.md) · [🏠 Master Hub](../../../README.md)

| Attribute                    | Details                                                                                                                                                               |
| :--------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Case ID**                  | `M07`                                                                                                                                                                 |
| **Difficulty Level**         | 🟡 **Medium** (`45–60 mins` — Standard SWE Bar)                                                                                                                       |
| **Task Archetype**           | Bugfix + Feature Extension + Algorithmic Scale                                                                                                                        |
| **Source GitHub Repository** | [`executablebooks/markdown-it-py`](https://github.com/executablebooks/markdown-it-py) (Python) · [`markedjs/marked`](https://github.com/markedjs/marked) (TypeScript) |
| **Target Files**             | `markdown_it/rules_block/table.py`, `tests/test_port/test_fixtures.py`                                                                                                |
| **Supported Languages**      | `Python`, `TypeScript`, `Rust`                                                                                                                                        |
| **Primary AI Traps**         | Splitting pipe `\|` inside inline code backticks `` `a \| b` `` · Even vs. odd backslash escape parity (`\\\|` vs `\|`) · Catastrophic regex backtracking (ReDoS)     |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Source Repository & Pull Request (Confidential)

| Field                              | Value                                      |
| :--------------------------------- | :----------------------------------------- |
| **Repository**                     | `https://github.com/markedjs/marked`       |
| **Base SHA (pre-merge)**           | `ef0704c58459e927c805b92a5cc7d0c629e6fe43` |
| **Merge SHA (reference solution)** | `4ee44f7f2167bec4079255e32b520dd47f16486c` |
| **Test Command**                   | `npm test`                                 |

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/markedjs/marked.git interview-workspace
cd interview-workspace
git checkout ef0704c58459e927c805b92a5cc7d0c629e6fe43
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
npm test
```

### Reproducibility Verification

- **Base SHA (`ef0704c58459`)**: the test suite must contain at least one failing test related to the issue.
- **Merge SHA (`4ee44f7f2167`)**: the same tests must pass after checkout.

### Files Changed (Reference Solution)

- src/Lexer.ts, src/Tokenizer.ts

### Failing Tests to Enable

- Failing tests to enable/verify: quadratic_unterminated_links.cjs. Run the test command to confirm red on Base SHA and green on Merge SHA.

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
>
> You are working on our GFM (GitHub Flavored Markdown) Table block parser. You have full access to the AI Assistant and the test runner.
>
> ### What We Need You to Do
>
> Users rendering technical documentation tables have reported two bugs and requested one feature extension:
>
> 1. **Bug A — Pipes Inside Inline Code Spans & Backslash Escape Parity**:
>    - In Markdown tables, `|` separates columns **unless**:
>      - It is preceded by an **odd** number of backslashes (e.g., `\|` or `\\\|` is an escaped literal pipe `|`, whereas `\\|` is an escaped backslash `\` followed by a **real** column separator `|`!).
>      - It appears inside a matched inline code span (e.g., ``| `x | y` |`` or `|`x | `| y`` | ``). Note: if a backtick run is **unclosed** on that line (e.g., `` |`unclosed | next_col | ``), the backtick is literal text and the `|` **does** act as a column separator.
> 2. **Bug B — Linear $O(N)$ Performance Requirement (No ReDoS)**:
>    - Malformed lines with 10,000 backticks or pipes must parse in `< 20ms` without catastrophic regex backtracking.
> 3. **Feature Extension — Empty-Cell Colspan & Column Normalization**:
>    - Support consecutive unescaped pipes (or explicit colspan attribute generation on `td`/`th` tokens when configured) and ensure rows with fewer cells than the header row are padded with empty cells while rows with excess cells are truncated to match the header column count.
>
> ### Examples
>
> - ``| `a | b` | c |`` → **2 cells**: ``"`a | b`"`` and `"c"`
> - `| a \| b | c |` → **2 cells**: `"a | b"` and `"c"`
> - `| a \\| b |` → **2 cells**: `"a \\"` and `"b"` _(even number of backslashes before `|` means `|` is NOT escaped!)_
> - ``| `unclosed | b |`` → **2 cells**: ``"`unclosed"`` and `"b"` _(backtick was never closed on the row!)_
>
> Please explore the table parser in the codebase, re-enable any commented-out table tests, implement a linear-time $O(N)$ row scanner that handles escape parity and matched backtick runs accurately, and verify edge cases with unit tests.

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Trusting the first plausible fix

- **What Naive AI Writes**: A minimal edit that makes the happy path pass but ignores the edge cases exercised by the real PR (`fast-fail link tokenizing when no ')' remains ahead`).
- **Why It Fails**: The PR touches `src/Lexer.ts, src/Tokenizer.ts`; a shallow change leaves the underlying defect (ordering, caching, type resolution, or retry semantics) in place, so hidden tests still fail.
- **Correct Fix**: Reproduce the failing tests on Base SHA, then implement the same behavior change as the merged PR (study its diff), including edge cases and invariants.

### Trap 2: Over-editing unrelated code

- **What Naive AI Writes**: Refactors surrounding modules "while at it", changing public APIs.
- **Why It Fails**: Breaks callers and the hidden regression tests; the reference solution is minimal and scoped to the PR's changed lines.
- **Correct Fix**: Limit edits to the files/lines indicated by the failing tests; keep diffs small and behavior-focused.

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Trace the current behavior in `src/Lexer.ts, src/Tokenizer.ts, quadratic_unterminated_links.cjs` and identify why the failing tests fail on Base SHA."_
2. **Step 2 (`Plan`)**:
   - Reproduce with the test command; list the minimal files to change.
3. **Step 3 (`Prompt`)**:
   - Prompt 1: Implement the fix matching the merged PR's behavior, scoped to the failing tests.
   - Prompt 2: Add/adjust tests for edge cases (empty input, boundary values, error paths).
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Run the full test command; confirm all previously-failing tests pass and no regressions.

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

|   #   | Criterion                        | Strong Hire / Hire (`Score 3–4`)                                                                                                                                                                | No Hire / Blind Vibe-Coder (`Score 1–2`)                                                                 |
| :---: | :------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------- |
| **1** | **Problem Decomposition**        | Isolates row cell-splitting into a pure, linear-time scanner function and tests it on tricky strings before wiring into AST token emission.                                                     | Lets AI rewrite the entire `table()` AST rule with complex regular expressions.                          |
| **2** | **Prompt Context Quality**       | Explicitly specifies: (1) odd/even backslash parity, (2) exact backtick run-length matching (`k` opening backticks require `k` closing backticks), and (3) unclosed backticks do not mask `\|`. | Prompts _"Fix pipe splitting inside code blocks in `table.py`"_.                                         |
| **3** | **Not Blindly Trusting AI**      | Immediately rejects `re.split(r'(?<!\\)\|', ...)` and single-pass `in_code = not in_code` toggle bugs.                                                                                          | Accepts `re.split(r'(?<!\\)\|')` or naive `in_code` toggle without testing unclosed backticks or `\\\|`. |
| **4** | **Code Reading Speed**           | Understands `StateBlock` line offsets (`bMarks`, `eMarks`) and token generation in `table.py` within 8 minutes.                                                                                 | Confuses block-level table parsing with inline-level token parsing.                                      |
| **5** | **Bug & Edge-Case Discovery**    | Tests `\\\|`, `\\\\\|`, multi-backtick code spans, unclosed backticks, and escaped pipes inside code spans.                                                                                     | Misses `\\\|` (even backslashes) or unclosed backticks.                                                  |
| **6** | **Testing Before Claiming Done** | Runs full `pytest` suite plus a 20,000-char stress line to verify `< 20ms` linear runtime.                                                                                                      | Only runs 1–2 happy-path table tests.                                                                    |
| **7** | **Explaining Correctness**       | Explains CommonMark backtick matching rules (exact run-length `k` without backslash escaping inside code spans) and $O(N)$ time complexity.                                                     | Cannot explain why `(?<!\\)\|` fails on `\\\|`.                                                          |

### Interviewer Probing Questions (Final 10 Minutes)

1. **Q**: _"Inside a Markdown inline code span like `` `a \| b` ``, does `\` escape the `|` or is `\` treated as a literal character?"_  
   **Expected Answer**: Inside a CommonMark code span, backslashes are always treated as literal characters (so `` `\` `` is a valid code span containing one backslash!). What protects the `|` inside `` `a \| b` `` is the matched pair of backticks, whereas `|` after `` `\` `` in ``| `\` | b |`` is outside the closed code span and _is_ a real column separator!

2. **Q**: _"Why is a backslash-parity state machine safer than a regex for splitting table cells?"_
   **Expected Answer**: Regex cannot correctly handle escaped pipes inside inline code spans.
