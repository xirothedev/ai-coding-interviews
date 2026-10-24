# H09 — ANSI Wide-Character Table Layout Engine & Wrapping Perf Cliff

[⬅️ Back to Hard Catalog](README.md) · [🏠 Master Hub](../../../README.md)

| Attribute                    | Details                                                                                         |
| :--------------------------- | :---------------------------------------------------------------------------------------------- |
| **Case ID**                  | `H09`                                                                                           |
| **Difficulty Level**         | 🔴 **Hard** (`60–75 mins` — Senior / Staff Bar)                                                 |
| **Task Archetype**           | Toy-vs-Prod Scale Optimization + Edge-Case Bugfix                                               |
| **Source GitHub Repository** | [`Textualize/rich`](https://github.com/Textualize/rich)                                         |
| **Target Files**             | `rich/cells.py`, `rich/text.py`, `tests/test_cells.py`, `tests/test_text.py`                    |
| **Supported Languages**      | `Python`                                                                                        |
| **Hard Taxonomy Pillars**    | Pillar 2 (Toy vs. Prod $O(N^2)$ Perf Cliff) · Pillar 3 (Unicode Terminal Cell-Width Invariants) |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Source Repository & Pull Request (Confidential)

| Field                              | Value                                      |
| :--------------------------------- | :----------------------------------------- |
| **Repository**                     | `https://github.com/Textualize/rich`       |
| **Base SHA (pre-merge)**           | `5f0219786bbaf994061011df087602d5edff5d66` |
| **Merge SHA (reference solution)** | `d39626143036188cb2c9e1619e836540f5b627f8` |
| **Test Command**                   | `pytest`                                   |

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/Textualize/rich.git interview-workspace
cd interview-workspace
git checkout 5f0219786bbaf994061011df087602d5edff5d66
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
pytest
```

### Reproducibility Verification

- **Base SHA (`5f0219786bba`)**: the test suite must contain at least one failing test related to the issue.
- **Merge SHA (`d39626143036`)**: the same tests must pass after checkout.

### Files Changed (Reference Solution)

- rich/cells.py, rich/_cell_widths.py

### Failing Tests to Enable

- Failing tests to enable/verify: test_cells.py. Run the test command to confirm red on Base SHA and green on Merge SHA.

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
>
> You are working inside `Textualize/rich`, Python's terminal rendering engine. You may use the AI Assistant freely. We are evaluating how you handle Unicode terminal cell-width invariants and optimize an algorithmic bottleneck from $O(L \times S)$ to $O(S \log L)$.
>
> ### What We Need You to Do
>
> In terminal UIs, character width is measured in **cells** (`cell_len`), not Python string length:
>
> - Standard ASCII characters (`"a"`, `"1"`) = **1 cell**
> - Combining marks / zero-width characters (`"\u0301"`) = **0 cells**
> - Wide CJK ideographs (`"你"`, `"好"`) & Emojis (`"🚀"`) = **2 cells**
>
> Users have reported two critical bugs:
>
> 1. **Wide-Character Cropping & Wrapping Alignment**:
>    - In a multi-byte string with a target display width (where each character is 2 cells wide): only `"你好"` (4 cells) fits inside 5 cells because `"世"` requires 2 cells (the accumulated width exceeds the target). However, `set_cell_size(..., 5)` must return a string of **exact cell length `5`** by padding the remaining 1-cell gap with a space: `"你好 "` (the resulting display width matches the target).
>    - In `chop_cells(text, max_size=1)` on `"你好"`, because a 2-cell character can never fit inside `max_size=1`, the function must **not** enter an infinite loop emitting empty strings `""` forever.
>    - Zero-width combining characters (e.g., `"e\u0301"`) must never be split onto a new line separated from their preceding base character.
> 2. **Quadratic Performance Cliff in `Text.divide(offsets)`**:
>    - `Text.divide(offsets)` splits a `Text` object (with `self._spans: list[Span]`) into `L` line `Text` objects at character indices `offsets`.
>    - Currently, splitting a `Text` with `10,000` spans (including both short token spans and full-document background spans `Span(0, 50000, "on blue")`) across `4,000` lines takes `> 4 seconds` ($O(L \times S)$).
>    - Optimize `Text.divide()` so the 10,000-span / 4,000-line benchmark completes in **`< 0.10 seconds`** while preserving 100% of overlapping and multi-line spans.
>
> Please explore the cell-measurement and text-wrapping modules in the codebase, re-enable any commented-out wide-character and benchmark tests, fix the cell-boundary bugs, and refactor `Text.divide` to sub-quadratic complexity.

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Trusting the first plausible fix

- **What Naive AI Writes**: A minimal edit that makes the happy path pass but ignores the edge cases exercised by the real PR (`Fix width measurement of 353 emoji`).
- **Why It Fails**: The PR touches `rich/cells.py, rich/_cell_widths.py, rich/emoji.py`; a shallow change leaves the underlying defect (ordering, caching, type resolution, or retry semantics) in place, so hidden tests still fail.
- **Correct Fix**: Reproduce the failing tests on Base SHA, then implement the same behavior change as the merged PR (study its diff), including edge cases and invariants.

### Trap 2: Over-editing unrelated code

- **What Naive AI Writes**: Refactors surrounding modules "while at it", changing public APIs.
- **Why It Fails**: Breaks callers and the hidden regression tests; the reference solution is minimal and scoped to the PR's changed lines.
- **Correct Fix**: Limit edits to the files/lines indicated by the failing tests; keep diffs small and behavior-focused.

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Trace the current behavior in `rich/cells.py, rich/_cell_widths.py, rich/emoji.py, test_cells.py` and identify why the failing tests fail on Base SHA."_
2. **Step 2 (`Plan`)**:
   - Reproduce with the test command; list the minimal files to change.
3. **Step 3 (`Prompt`)**:
   - Prompt 1: Implement the fix matching the merged PR's behavior, scoped to the failing tests.
   - Prompt 2: Add/adjust tests for edge cases (empty input, boundary values, error paths).
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Run the full test command; confirm all previously-failing tests pass and no regressions.

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

|   #   | Criterion                        | Strong Hire / Hire (`Score 3–4`)                                                                                                                                   | No Hire / Blind Vibe-Coder (`Score 1–2`)                                                                                 |
| :---: | :------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------- | :----------------------------------------------------------------------------------------------------------------------- |
| **1** | **Problem Decomposition**        | Tackles `rich/cells.py` character width correctness first, then optimizes `Text.divide()` in `rich/text.py`.                                                       | Mixes cell-width logic with span binary search in a single prompt.                                                       |
| **2** | **Prompt Context Quality**       | Instructs AI to bisect the monotonic `line_ranges` per `Span` (or maintain an active interval heap) so multi-line spans (`span.start < line_start`) are preserved. | Prompts _"Use binary search to speed up `Text.divide`"_, getting the broken `bisect_left(span_starts, line_start)` code. |
| **3** | **Not Blindly Trusting AI**      | Immediately asks _"What happens if a Span starts on line 0 and ends on line 50?"_ when reviewing AI's binary search diff.                                          | Applies AI's `bisect_left(span_starts, line_start)` and is baffled when multi-line style tests fail.                     |
| **4** | **Code Reading Speed**           | Understands `Span(start, end, style)` and `_cell_widths` table in `rich/cells.py` within 10 minutes.                                                               | Confuses character index (`len(str)`) offsets in `Span` with terminal cell widths (`cell_len`).                          |
| **5** | **Bug & Edge-Case Discovery**    | Tests `max_size=1` on `"你好"`, combining accents `"e\u0301"`, and a full-text `Span(0, N)` overlapping small spans.                                               | Misses the `max_size=1` infinite loop or combining character split.                                                      |
| **6** | **Testing Before Claiming Done** | Runs `pytest` on both `test_cells.py` and `test_text.py` and measures wall-clock time on the 10k-span test.                                                        | Claims done without running `test_text.py` or checking benchmark timing.                                                 |
| **7** | **Explaining Correctness**       | Clearly explains why `line_ranges` are disjoint monotonic intervals (making `bisect` exact), whereas `spans` can nest arbitrarily.                                 | Cannot explain why bisecting `spans` by `start` misses long intervals.                                                   |

### Interviewer Probing Questions (Final 10 Minutes)

1. **Q**: _"Why can we use standard binary search (`bisect`) on `line_ranges` for each `Span`, whereas we CANNOT use simple binary search on `spans` sorted by `span.start` for each `line`?"_  
   **Expected Answer**: `line_ranges` partition `[0, N]` into strictly disjoint, non-overlapping intervals (`end[i] == start[i+1]`), so both `start` and `end` arrays are monotonically increasing. `spans`, however, can overlap and nest arbitrarily (a span starting at `0` can end at `10,000`, while a span starting at `5` ends at `10`), so sorting `spans` by `start` does not sort them by `end`!

2. **Q**: _"Why does `max_width=1` risk an infinite loop on 2-cell characters?"_
   **Expected Answer**: A 2-cell char cannot fit in width 1; the chopper must advance by cell width, not by one.
