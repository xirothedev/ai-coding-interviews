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

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/executablebooks/markdown-it-py.git markdown-interview
cd markdown-interview
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
pytest
```

### Seeded Defects to Inject Before the Session

In `markdown_it/rules_block/table.py` (`escapedSplit(string: str) -> list[str]` and `table` block rule):

1. **Bug 1 (Native Escape-Parity Bug in `escapedSplit` & Naive Pipe Splitting Inside Code Spans)**:
   - Notice that `escapedSplit(string: str) -> list[str]` in `markdown_it/rules_block/table.py` (line 50) **already has a native even-backslash escape parity bug**: at the end of its character loop, it sets `isEscaped = ch == "\\"` instead of toggling `isEscaped = not isEscaped` when `ch == "\\"`, so an **even** number of backslashes before a pipe (`| a \\| b |`) leaves `isEscaped = True` and fails to split the column!
   - Furthermore, `escapedSplit` does not track inline code backtick spans (``| `a | b` | c |``), splitting on raw pipes inside inline code!
2. **Commented Tests**: Comment out the inline-code pipe tests, even-backslash escape tests (`| a \\| b |`), and colspan/long-line benchmark tests in `tests/test_port/test_fixtures.py`.

---

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

### Trap 1: Using Regex `r'(?<!\\)\|'` to Split Table Cells

- **What Naive AI Writes**:
  ```python
  cells = re.split(r'(?<!\\)\|', line)
  ```
- **Why It Fails on ALL 3 Counts**:
  1. Fails on `| a \\| b |`: Because the character before `|` is `\`, `(?<!\\)\|` thinks `|` is escaped, even though the first `\` escaped the second `\`!
  2. Splits pipes inside inline code spans: ``| `a | b` |`` is split in the middle of the code span!
  3. If the AI tries to write a giant nested regex to match balanced backticks and escapes, it either fails on multi-backtick spans (``` ``a ` | b`` ```) or triggers **catastrophic $O(2^N)$ ReDoS backtracking** on unclosed backticks!

### Trap 2: Greedy Single-Pass Backtick State Machine Failing on Unclosed Backticks

- **What Naive AI Writes**:
  - Toggles `in_code = not in_code` whenever it sees `` ` `` in a single pass.
- **Why It Fails**:
  1. If a cell contains an unclosed backtick ``| `foo | bar |``, toggling `in_code = True` at `` `foo `` swallows the rest of the entire table row as a single cell instead of recognizing that the backtick was never closed!
  2. Inside ``` ``a ` | b`` ```, a single `` ` `` does NOT close a double-backtick ` `` ` span!
- **The Correct $O(N)$ Solution**:
  - Track `escaped` boolean parity (`escaped = not escaped` on `\`, reset to `False` on any other char).
  - Pre-scan (or track backtick run lengths `k`) so a run of `k` backticks only opens a code span if a matching closing run of **exact length `k`** exists later on the same line!

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Read `markdown_it/rules_block/table.py` and trace how lines are split into cells and when inline tokenization happens."_
2. **Step 2 (`Plan`)**:
   - Design an $O(N)$ character scanner for splitting a table row that:
     1. Tracks backslash escape parity (`backslash_count % 2 == 1`) outside code spans.
     2. Identifies matched backtick runs of exact length `k` (ignoring unclosed backtick runs!).
3. **Step 3 (`Prompt`)**:
   - Prompt the row-splitting scanner function in isolation and unit-test it on the 4 tricky cases (`\|`, `\\|`, `` `a | b` ``, and `` `unclosed | b ``).
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Verify no backtracking regexes are used and run `pytest`.

---

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
