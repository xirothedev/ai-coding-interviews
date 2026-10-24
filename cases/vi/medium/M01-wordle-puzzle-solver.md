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

### Workspace Layout (Matching Meta CoderPad Environment in `natashalukmanto/dsa`)

```bash
git clone https://github.com/natashalukmanto/dsa.git meta-puzzle-interview
cd meta-puzzle-interview/others/meta/puzzle
pytest
```

```text
others/meta/puzzle/
├── data/
│   └── up_to_six_letters.txt       # 40,000+ words of lengths 1 to 6
├── dictionary.py                   # get_test_dictionary() & get_prod_dictionary()
├── main.py                         # Entrypoint runner
├── puzzle.py                       # Match(YES, MOVE, NO), Puzzle.guess(), Puzzle.admit_defeat() / admitDefeat()
├── solver.py                       # Solver stub to implement
├── puzzle_test.py                  # Unit tests for Puzzle (or test_puzzle.py; some commented out)
└── solver_test.py                  # Unit tests for Solver (or test_solver.py; some commented out)
```

### Seeded Defects in the Starter Codebase

1. **Bug 1 (`dictionary.py`)**: `_read_file_dictionary("up_to_six_letters.txt")` only searches `[Path("data")]` (relative to current working directory) and raises `FileNotFoundError` when tests are run from another directory or if blank/uppercase lines exist.
2. **Bug 2 (`puzzle.py` — Duplicate Letter `Match.MOVE` Bug)**: `Puzzle.guess(word)` checks `elif letter in self._secret_word: result.append(Match.MOVE)` in a single pass without decrementing available letter counts!
   - Example: If `secret = "area"` and `guess = "aaaa"`, `Puzzle.guess("aaaa")` returns `[YES, MOVE, MOVE, YES]` instead of `[YES, NO, NO, YES]`.
   - Example: If `secret = "aloe"` and `guess = "ally"`, the second `"l"` in `"ally"` returns `Match.MOVE` even though `"aloe"` only has one `"l"` (already matched at index 1!).
3. **Commented Tests**: Commented-out unit tests in `puzzle_test.py` (`test_puzzle.py`) and `solver_test.py` (`test_solver.py`) for duplicate-letter guesses, variable-length words, and `get_prod_dictionary()`.

---

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
>
> Use this session to solve a realistic multi-file engineering problem with the AI Assistant.
>
> ### The Puzzle
>
> I've written a new word game, and it works like this:
>
> - `Puzzle` has a secret word chosen from a bundled dictionary containing words of **1 to 6 letters**.
> - The player needs to guess the secret word, ideally in as few guesses as possible.
> - When you guess a word via `Puzzle.guess(word)`, you get a list of `Match` statuses for each letter in your guess:
>   - `Match.YES` if the secret word has that exact letter in that exact spot.
>   - `Match.MOVE` if that letter could be moved to another spot to be correct (respecting letter frequency counts—excess duplicate letters in a guess beyond how many exist in the secret word must be marked `Match.NO`!).
>   - `Match.NO` if the letter can't be used.
> - If you can't guess it, you can give up via `Puzzle.admit_defeat()` (or `Puzzle.admitDefeat()`) to reveal the secret word.
>
> ### Examples of `Puzzle.guess`
>
> - Secret = `"able"`, Guess = `"ably"` → `[Match.YES, Match.YES, Match.YES, Match.NO]`
> - Secret = `"aloe"`, Guess = `"ally"` → `[Match.YES, Match.YES, Match.NO, Match.NO]` _(Second `'l'` is `NO` because `'aloe'` has only one `'l'`, already matched at index 1)_
> - Secret = `"area"`, Guess = `"aaaa"` → `[Match.YES, Match.NO, Match.NO, Match.YES]`
>
> ### What We Need You to Do
>
> 1. **Explore & Run the Game**: Explore the repository to see how the dictionary loader, puzzle engine, solver, and entrypoint runner fit together, and run the entrypoint script to see its current behavior.
> 2. **Run & Re-enable Unit Tests**: Run the existing unit test suites for the puzzle and solver, find any commented-out test cases, and re-enable them.
> 3. **Fix Existing Dictionary & Hint Bugs**: Fix the existing bugs in dictionary loading and duplicate-letter hint evaluation so all puzzle unit tests pass.
> 4. **Implement the Automated `Solver`**: Implement `Solver` so it plays the game and reliably solves puzzles across both the small test dictionary and the full 40,000-word production dictionary, averaging `<= 5.0` guesses per word and completing 100 production games in `< 2.0 seconds`.
> 5. **Use the AI Assistant** as much or as little as you would like, and be ready to explain why your solution is correct.

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Single-Pass `Match.MOVE` Over-Counting Duplicate Letters

- **What Naive AI Writes**:
  ```python
  return [
      Match.YES if g == s else (Match.MOVE if g in secret else Match.NO)
      for g, s in zip(guess, secret)
  ]
  ```
- **Why It Fails**: If `secret = "aloe"` and `guess = "ally"`, index 1 (`'l' == 'l'`) consumes the only `'l'` in `"aloe"`. A single-pass check sees `'l' in "aloe"` at index 2 and returns `Match.MOVE`! Even worse, if `secret = "abbey"` and `guess = "babes"`, index 0 `'b'` would consume a `'b'` before index 2's exact `Match.YES`!
- **Correct Fix (Two-Pass Frequency Algorithm)**:
  ```python
  def evaluate_guess(secret: str, guess: str) -> list[Match]:
      result = [Match.NO] * len(guess)
      remaining = Counter(secret)
      # Pass 1: Exact matches (Match.YES) MUST be claimed first!
      for i, (s_char, g_char) in enumerate(zip(secret, guess)):
          if s_char == g_char:
              result[i] = Match.YES
              remaining[g_char] -= 1
      # Pass 2: Misplaced matches (Match.MOVE) consume remaining unmatched counts
      for i, g_char in enumerate(guess):
          if result[i] == Match.NO and remaining[g_char] > 0:
              result[i] = Match.MOVE
              remaining[g_char] -= 1
      return result
  ```

### Trap 2: Inconsistent Filtering in `Solver` + Variable Word Lengths (`1..6`)

- **What Naive AI Writes**:
  - Hardcodes `word_len = 5` (crashing on `get_test_dictionary()` which uses 4-letter words and `up_to_six_letters.txt` which has 1-to-6 letter words!).
  - Writes ad-hoc filtering rules (`if match == Match.NO: candidates = [w for w in candidates if ch not in w]`) which **eliminates the true secret word** when a duplicate letter gets `Match.YES` at pos 1 and `Match.NO` at pos 2!
- **The Brilliant Fix**: Reuse `evaluate_guess(candidate, guess) == feedback`!
  - A candidate word `w` in `candidates` is consistent with `feedback` **if and only if** `evaluate_guess(secret=w, guess=last_guess) == feedback`! This is 1 line of code and handles duplicate letters with 100% mathematical perfection!

### Trap 3: $O(|C|^2)$ Minimax / Entropy Timeout on `get_prod_dictionary()`

- **Why It Fails**: Computing full pairwise entropy over 40,000 words takes $1.6 \times 10^9$ evaluations (`> 60 seconds`).
- **Correct Fix**: Score remaining candidates in $O(|C| \cdot L)$ time using positional character frequencies (preferring words with high-frequency distinct letters in the first 1–2 guesses, or pre-grouping dictionary by `len(word)`).

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Read `dictionary.py`, `puzzle.py`, `solver.py`, `test_puzzle.py`, and `test_solver.py`. List the commented-out tests and explain what bugs currently exist in `dictionary.py` and `puzzle.py`."_
2. **Step 2 (`Plan`)**:
   - Candidate plans: (1) fix path resolution in `dictionary.py`, (2) extract pure helper `evaluate_guess(secret, guess)` using the 2-pass `Counter` algorithm in `puzzle.py`, (3) implement `Solver` by filtering `evaluate_guess(cand, guess) == feedback` and scoring candidates via $O(|C| \cdot L)$ positional letter frequency.
3. **Step 3 (`Prompt`)**:
   - Prompt 1: Fix `dictionary.py` and 2-pass `evaluate_guess` in `puzzle.py`; run `test_puzzle.py`.
   - Prompt 2: Implement `Solver` in `solver.py` using `evaluate_guess` for filtering + $O(N)$ frequency heuristic.
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Verify `Solver` never uses `if ch not in w` on `Match.NO`, handles lengths 1–6, and passes `test_solver.py` on `get_prod_dictionary()`.

---

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
