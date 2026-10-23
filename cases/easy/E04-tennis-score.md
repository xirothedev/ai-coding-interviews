# E04 — Tennis Match Tie-Break & Advantage State Machine

[⬅️ Back to Easy Catalog](README.md) · [🏠 Master Hub](../../README.md)

| Attribute                    | Details                                                                                                                                                     |
| :--------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Case ID**                  | `E04`                                                                                                                                                       |
| **Difficulty Level**         | 🟢 **Easy** (`30–45 mins` — Junior / Mid Bar)                                                                                                               |
| **Task Archetype**           | Bugfix + Feature Extension (State Machine)                                                                                                                  |
| **Source GitHub Repository** | [`emilybache/Tennis-Refactoring-Kata`](https://github.com/emilybache/Tennis-Refactoring-Kata)                                                               |
| **Target Files**             | `tennis.py` / `tennis3.py` & `tennis_test.py` _(or `TypeScript/`, `go/`, `java/`, `rust/`, `csharp/`)_                                                      |
| **Supported Languages**      | `Python`, `TypeScript`, `Go`, `Java`, `Rust`, `C#`                                                                                                          |
| **Primary AI Traps**         | Allowing `won_point()` after game is already won (turning `"Win for player1"` back into `"Deuce"`!) · Emitting `"Advantage"` at `7–6` during Tie-Break mode |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/emilybache/Tennis-Refactoring-Kata.git tennis-interview
cd tennis-interview/python # (or TypeScript / go / java / rust / csharp)
rm -rf ../.git && git init && git add . && git commit -m "Initial interview baseline"
pytest
```

### Seeded Defects to Inject Before the Session

1. **Bug 1 (High-Score Overflow in `TennisGame3`)**: In `TennisGame3.score()`, seed an array-index or bit-arithmetic bug when deuce extends to high point counts (e.g., `16–16` or `16–15`), or when custom player names (`"Roger"`, `"Rafa"`) are passed instead of `"player1"` / `"player2"` in `TennisGame1.won_point()`.
2. **Commented Tests**: Comment out `test_custom_player_names`, `test_cannot_score_after_game_won`, and `test_tie_break_mode` in `tennis_test.py`.

---

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
>
> You are working on the Tennis Scoring Engine (`Tennis-Refactoring-Kata`). You have full access to the AI Assistant and `pytest`.
>
> ### Problem Context
>
> 1. **Bug in Custom Player Names & High Deuce Counts**:
>    - Look at how `won_point(player_name)` and `score()` handle player names other than `"player1"` / `"player2"` (e.g., `TennisGame("Serena", "Venus")`) and high deuce scores (`15–15`, `16–15`). Fix any hardcoded `"player1"` assumptions!
> 2. **Terminal State Guard (Post-Win Immutability)**:
>    - Once a game has reached a terminal `"Win for <player>"` state, calling `won_point()` again MUST raise a `ValueError("Game is already over")` (or language-equivalent exception) instead of continuing to mutate points (which currently allows the losing player to score twice after losing `4–2` and turn a finished game back into `"Deuce"`!).
> 3. **New Feature — Set Tie-Break Mode (`is_tie_break: bool = False`)**:
>    - Add an optional `is_tie_break: bool = False` parameter to the constructor:
>      - In Tie-Break mode, scores are formatted using **raw numerical points** (`"0-0"`, `"1-0"`, `"6-6"`, `"7-6"`, `"8-8"`), NEVER `"Love"`, `"Fifteen"`, `"Deuce"`, or `"Advantage"`.
>      - A player wins a Tie-Break when they reach **at least `7` points AND lead by `>= 2` points** (e.g., `7–0`, `7–5`, `8–6`, `12–10` → `"Win for <player>"`). At `6–6` or `7–6`, the game is still ongoing and `score()` returns `"6-6"` or `"7-6"`!
>
> ### Your Tasks
>
> 1. **Explore & Run Tests**: Inspect `tennis1.py`, `tennis2.py`, `tennis3.py`, and `tennis_test.py`. Run `pytest`.
> 2. **Uncomment & Fix Existing Bugs**: Uncomment the custom-player-name and high-deuce tests and fix the bugs.
> 3. **Implement Post-Win Guard & Tie-Break Mode**: Add terminal state protection and `is_tie_break=True` support while keeping all existing parameterized tests passing.
> 4. **Verify Edge Cases**: Test scoring after `"Win for Serena"` raises `ValueError`, test `7–6` in Tie-Break returns `"7-6"` (NOT `"Win"` and NOT `"Advantage"`), and test `8–6` in Tie-Break returns `"Win for <player>"`.

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Reusing Standard `p1 >= 4` Win Check in Tie-Break Mode or Checking `is_finished()` Only on Standard Threshold (`>= 4`)

- **What Naive AI Writes**:
  ```python
  def is_game_over(self) -> bool:
      return (self.p1 >= 4 or self.p2 >= 4) and abs(self.p1 - self.p2) >= 2
  ```
- **Why It Fails**: In `is_tie_break = True` mode, reaching `4–2` is NOT the end of the game—tie-break requires `>= 7` points (with a 2-point lead)! If `is_game_over()` uses `4` instead of `target = 7 if self.is_tie_break else 4`, calling `won_point()` at `4–2` during a tie-break falsely raises `ValueError("Game is already over")`!
- **Correct Fix**:
  ```python
  win_threshold = 7 if self.is_tie_break else 4
  def is_finished(self) -> bool:
      return max(self.p1, self.p2) >= win_threshold and abs(self.p1 - self.p2) >= 2
  ```

### Trap 2: Hardcoded `if player_name == "player1":` in `won_point`

- **Why It Fails**: In `TennisGame1`, `if player_name == "player1": self.p1 += 1 else: self.p2 += 1` credits `"Serena"`'s points to `p2` (`"Venus"`) because `"Serena" != "player1"`! Always compare against `self.player1_name` and `self.player2_name` (and raise `ValueError` for unknown player names).

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Check how `player1Name` and `player2Name` are used in `won_point` and `score` across the tennis classes."_
2. **Step 2 (`Plan`)**:
   - Define `win_threshold = 7 if self.is_tie_break else 4` and `is_finished()`; validate `player_name in (self.player1_name, self.player2_name)` and `not self.is_finished()` in `won_point()`; branch `score()` cleanly for `is_finished()`, `is_tie_break`, and standard scoring.
3. **Step 3 (`Prompt`)** & **Step 4 (`Review`)**:
   - Verify `is_finished()` uses `7` for tie-breaks and `4` for standard games.

---

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

|   #   | Criterion                        | Strong Hire / Hire (`Score 3–4`)                                                                                                          | No Hire / Blind Vibe-Coder (`Score 1–2`)                                                           |
| :---: | :------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------- |
| **1** | **Problem Decomposition**        | Unifies terminal state detection (`is_finished` parameterized by `win_threshold = 7 if is_tie_break else 4`) before formatting strings.   | Hacks separate `if` checks into `won_point` and `score` with inconsistent thresholds (`4` vs `7`). |
| **2** | **Prompt Context Quality**       | Specifies `self.player1_name` comparison, `win_threshold = 7 if is_tie_break else 4`, and numerical `"X-Y"` tie-break formatting.         | Prompts _"Add tie break mode to tennis.py"_.                                                       |
| **3** | **Not Blindly Trusting AI**      | Catches the `win_threshold = 4` vs `7` bug inside `won_point()`'s terminal guard.                                                         | Accepts AI code that blocks `won_point()` at `4–2` during a 7-point tie-break!                     |
| **4** | **Code Reading Speed**           | Spots `if playerName == "player1":` bug in `TennisGame1` within 2 minutes.                                                                | Misses the hardcoded `"player1"` string check.                                                     |
| **5** | **Bug & Edge-Case Discovery**    | Tests `4–2` in tie-break (still ongoing!), `7–6` in tie-break (`"7-6"`), `8–6` in tie-break (`"Win"`), and unknown player name.           | Only tests `7–0` in tie-break and misses `4–2` and `7–6`.                                          |
| **6** | **Testing Before Claiming Done** | Runs the full parameterized test suite across all 30+ score combinations plus tie-break cases.                                            | Only runs 1 manual test.                                                                           |
| **7** | **Explaining Correctness**       | Explains the finite state machine transitions and why `is_finished()` is the single source of truth for both `won_point()` and `score()`. | Cannot explain what happens at `4–2` in tie-break mode if `won_point` checks `>= 4`.               |

### Interviewer Probing Questions (Final 10 Minutes)

1. **Q**: _"What happens in your code if a game is in Tie-Break mode, the score reaches `4–2`, and `won_point` is called for the 5th point?"_  
   **Expected Answer**: Since `win_threshold` is `7` in Tie-Break mode, `is_finished()` is `False` at `4–2`, so the 5th point is recorded normally (`"5-2"`).
