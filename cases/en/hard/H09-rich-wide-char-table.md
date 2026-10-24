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

- Re-enable any commented-out or skipped tests covering the issue; run `pytest` to confirm red on Base SHA and green on Merge SHA.

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
>    - In `set_cell_size("你好世界", 5)` (where each character is 2 cells wide): only `"你好"` (4 cells) fits inside 5 cells because `"世"` requires 2 cells (`4 + 2 = 6 > 5`). However, `set_cell_size(..., 5)` must return a string of **exact cell length `5`** by padding the remaining 1-cell gap with a space: `"你好 "` (`cell_len == 5`).
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

### Trap 1: Sorting Spans by `span.start` and Using `bisect` on `spans` per Line (Drops Multi-Line Outer Spans!)

- **What Naive AI Writes**:
  ```python
  # AI's broken "optimization" in Text.divide():
  sorted_spans = sorted(self._spans, key=attrgetter("start"))
  span_starts = [s.start for s in sorted_spans]
  for line_start, line_end in line_ranges:
      idx = bisect_left(span_starts, line_start) # <-- BUG!
      # Only checks spans where span.start >= line_start!
  ```
- **Why It Fails**: Suppose `Span(0, 1000, "bold")` covers the entire paragraph, and Line 2 is `(80, 160)`. Because `span.start == 0 < 80`, `bisect_left(span_starts, 80)` **skips `Span(0, 1000)` completely**, losing all multi-line styles on Line 2..N!
- **The Brilliant Fix (Invert the Loop — Bisect `line_ranges` per Span!)**:
  - `line_ranges` is **already a strictly disjoint, monotonically sorted array** of `(start, end)` intervals covering `[0, len(text)]`!
  - Instead of searching `spans` for each `line`, iterate each `Span(span_start, span_end, style)` once, and use binary search (`bisect_right` / `bisect_left`) on the `line_ranges` boundaries to find the exact slice of lines `[first_line_idx .. last_line_idx]` that this span overlaps!
  ```python
  # O(S log L + total_clipped_spans) - handles 100% of overlapping & multi-line spans!
  for span_start, span_end, style in self._spans:
      lower_bound = bisect_right(end_offsets, span_start)
      upper_bound = bisect_left(start_offsets, span_end)
      for line_index in range(lower_bound, upper_bound):
          ...
  ```

### Trap 2: Infinite Loop in `chop_cells(text, max_size=1)` on 2-Cell Characters

- **What Naive AI Writes**:
  ```python
  if total_width + char_width > max_size:
      lines.append("".join(current_line))
      current_line = [character] # <-- Wait: what if char_width (2) > max_size (1)?
  ```
  Or worse, pushes `character` back onto the queue without advancing the index when `current_line` is empty!
- **Correct Fix**: Ensure every step makes forward progress even when `char_width > max_size` and `current_line` is empty (or clamp/replace according to `chop_cells` contract).

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Read `rich/cells.py` (`set_cell_size`, `chop_cells`) and `rich/text.py` (`Text.divide`). Trace how `Text.divide` currently maps `self._spans` onto `lines`."_
2. **Step 2 (`Plan`)**:
   - Candidate recognizes that `line_ranges` are disjoint and sorted, so bisecting `line_ranges` for each `Span` is $O(S \log L)$ and never misses a long outer span!
3. **Step 3 (`Prompt`)**:
   - Prompt 1: Fix `set_cell_size` trailing space padding and `chop_cells` combining mark / `max_size=1` edge cases in `rich/cells.py`.
   - Prompt 2: Refactor `Text.divide` in `rich/text.py` by iterating `self._spans` and bisecting `line_ranges`.
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Run `pytest tests/test_cells.py tests/test_text.py` and verify the 10k-span benchmark runs in `< 0.10s`.

---

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
