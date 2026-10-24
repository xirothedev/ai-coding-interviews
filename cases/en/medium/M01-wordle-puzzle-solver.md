# M01 — Secret Word Puzzle & Entropy Solver Engine _(Meta Flagship)_

[⬅️ Back to Medium Catalog](README.md) · [🏠 Master Hub](../../../README.md)

| Attribute                    | Details                                                                                                                                                                                                                |
| :--------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Case ID**                  | `M01` _(Meta AI-Enabled SWE Practice Flagship)_                                                                                                                                                                        |
| **Difficulty Level**         | 🟡 **Medium** (`45–60 mins` — Standard SWE Bar)                                                                                                                                                                        |
| **Task Archetype**           | Bugfix + Solver Implementation + Toy-vs-Prod Scale                                                                                                                                                                     |
| **Source GitHub Repository** | [`natashalukmanto/dsa`](https://github.com/natashalukmanto/dsa) (`others/meta/puzzle`) · [`jason-chao/wordle-solver`](https://github.com/jason-chao/wordle-solver) · [`jonhoo/roget`](https://github.com/jonhoo/roget) |
| **Target Files**             | `others/meta/puzzle/dictionary.py`, `puzzle.py`, `solver.py`, `puzzle_test.py` (`test_puzzle.py`), `solver_test.py` (`test_solver.py`), `main.py`, `data/up_to_six_letters.txt`                                        |
| **Supported Languages**      | `Python`, `TypeScript`, `Go`, `Java`, `Rust`                                                                                                                                                                           |
| **Primary AI Traps**         | Duplicate-letter `Match.MOVE` bug · Variable word lengths (`1..6`) in `up_to_six_letters.txt` · $O(N^2)$ timeout on `get_prod_dictionary()`                                                                            |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Source Repository & Pull Request (Confidential)

| Field                              | Value                                      |
| :--------------------------------- | :----------------------------------------- |
| **Repository**                     | `https://github.com/jonhoo/roget`          |
| **Base SHA (pre-merge)**           | `4482ad13db3c556703565f81419223f365c4f96b` |
| **Merge SHA (reference solution)** | `a8ed2d8c9af28c5319bf7148b80a10031cd69424` |
| **Test Command**                   | `cargo test`                               |

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/jonhoo/roget.git interview-workspace
cd interview-workspace
git checkout 4482ad13db3c556703565f81419223f365c4f96b
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
cargo test
```

### Reproducibility Verification

- **Base SHA (`4482ad13db3c`)**: the test suite must contain at least one failing test related to the issue.
- **Merge SHA (`a8ed2d8c9af2`)**: the same tests must pass after checkout.

### Files Changed (Reference Solution)

- src/solver.rs

### Failing Tests to Enable

- Failing tests to enable/verify: the repository's existing tests covering this issue. Run the test command to confirm red on Base SHA and green on Merge SHA.

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Bug Report: Wordle Puzzle Solver Correctness
>
> The puzzle solver produces incorrect results for edge cases with few remaining candidates.
>
> ### Requirements
>
> - Handle small candidate sets without cutoff bugs.
> - Preserve correctness of guess scoring and elimination.
>
> ### Acceptance Criteria
>
> 1. Trace the solver logic.
> 2. Fix the cutoff edge case.
> 3. Verify with small candidate sets.

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Trusting the first plausible fix

- **What Naive AI Writes**: A minimal edit that makes the happy path pass but ignores the edge cases exercised by the real PR (`Fix issue with cutoffs for small number of remaining items.`).
- **Why It Fails**: The PR touches `src/solver.rs`; a shallow change leaves the underlying defect (ordering, caching, type resolution, or retry semantics) in place, so hidden tests still fail.
- **Correct Fix**: Reproduce the failing tests on Base SHA, then implement the same behavior change as the merged PR (study its diff), including edge cases and invariants.

### Trap 2: Over-editing unrelated code

- **What Naive AI Writes**: Refactors surrounding modules "while at it", changing public APIs.
- **Why It Fails**: Breaks callers and the hidden regression tests; the reference solution is minimal and scoped to the PR's changed lines.
- **Correct Fix**: Limit edits to the files/lines indicated by the failing tests; keep diffs small and behavior-focused.

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Trace the current behavior in `src/solver.rs` and identify why the failing tests fail on Base SHA."_
2. **Step 2 (`Plan`)**:
   - Reproduce with the test command; list the minimal files to change.
3. **Step 3 (`Prompt`)**:
   - Prompt 1: Implement the fix matching the merged PR's behavior, scoped to the failing tests.
   - Prompt 2: Add/adjust tests for edge cases (empty input, boundary values, error paths).
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Run the full test command; confirm all previously-failing tests pass and no regressions.

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

|   #   | Criterion                        | Strong Hire / Hire (`Score 3–4`)                                                                                                                     | No Hire / Blind Vibe-Coder (`Score 1–2`)                                                                                  |
| :---: | :------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------ |
| **1** | **Problem Decomposition**        | Fixes `dictionary.py` & `puzzle.py` first (`test_puzzle.py` green), then reuses `evaluate_guess` inside `solver.py`.                                 | Prompts AI to write `solver.py` immediately before fixing `puzzle.py` or running unit tests.                              |
| **2** | **Prompt Context Quality**       | Specifies the 2-pass `Match.YES` → `Match.MOVE` algorithm, variable word lengths `1..6`, and $O(N)$ scoring.                                         | Prompts _"Implement a Wordle solver in `solver.py`"_, getting hardcoded 5-letter $O(N^2)$ code.                           |
| **3** | **Not Blindly Trusting AI**      | Rejects AI's `if letter not in candidate` filter for `Match.NO` and rejects $O(N^2)$ entropy loops on prod dictionary.                               | Accepts `if letter not in candidate` for `Match.NO`, causing `Solver` to throw away the secret word on duplicate letters! |
| **4** | **Code Reading Speed**           | Notices `get_test_dictionary()` has 4-letter words while `up_to_six_letters.txt` has 1–6 letter words within 5 minutes.                              | Assumes all words are 5 letters long without reading `dictionary.py`.                                                     |
| **5** | **Bug & Edge-Case Discovery**    | Tests `"area"` vs `"aaaa"`, `"aloe"` vs `"ally"`, 1-letter words, and words with no matching letters.                                                | Misses the case where `Match.MOVE` appears _before_ `Match.YES` in the same word (`secret="abbey"`, `guess="babes"`).     |
| **6** | **Testing Before Claiming Done** | Uncomments all tests in `puzzle_test.py` (`test_puzzle.py`) and `solver_test.py` (`test_solver.py`) and benchmarks against `get_prod_dictionary()`.  | Only tests with `get_test_dictionary()` (38 words) and never runs `get_prod_dictionary()`.                                |
| **7** | **Explaining Correctness**       | Explains why `evaluate_guess(candidate, guess) == feedback` is an exact equivalence relation filter and why $O(N \cdot L)$ frequency scoring scales. | Cannot explain why `Match.NO` does not mean "letter is absent from the word."                                             |

### Interviewer Probing Questions (Final 10 Minutes)

1. **Q**: _"Suppose the secret word is `'aloe'` and the solver guesses `'ally'`, receiving `[YES, YES, NO, NO]`. What happens if your solver eliminates every word containing `'l'` when it sees `Match.NO` at index 2?"_  
   **Expected Answer**: It eliminates `'aloe'` (the true secret word!) and ends up with an empty candidate list. Checking `evaluate_guess(candidate, 'ally') == [YES, YES, NO, NO]` keeps `'aloe'` and eliminates words with two `'l'`s.
2. **Q**: _"Why must Pass 1 (`Match.YES`) complete across the entire word before Pass 2 (`Match.MOVE`) begins?"_  
   **Expected Answer**: If `secret = "abbey"` and `guess = "babes"`, a single left-to-right pass would give index 0 `'b'` a `Match.MOVE` and index 2 `'b'` a `Match.YES`, leaving `0` remaining `'b'`s—Wait: if `secret = "abide"` (one `'b'` at index 1) and `guess = "bbbbb"`, index 0 `'b'` would steal the only `'b'` as `Match.MOVE`, causing index 1's exact match `'b'` to become `Match.NO`!
