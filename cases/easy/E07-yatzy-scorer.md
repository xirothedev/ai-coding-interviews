# E07 — Yatzy Category Scorer & Wild Joker Die Rule

[⬅️ Back to Easy Catalog](README.md) · [🏠 Master Hub](../../README.md)

| Attribute                    | Details                                                                                                                                                                  |
| :--------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Case ID**                  | `E07`                                                                                                                                                                    |
| **Difficulty Level**         | 🟢 **Easy** (`30–45 mins` — Junior / Mid Bar)                                                                                                                            |
| **Task Archetype**           | Bugfix + Feature Extension                                                                                                                                               |
| **Source GitHub Repository** | [`emilybache/Yatzy-Refactoring-Kata`](https://github.com/emilybache/Yatzy-Refactoring-Kata)                                                                              |
| **Target Files**             | `yatzy.py` & `test_yatzy.py` _(or `TypeScript/`, `go/`, `java/`, `rust/`, `csharp/`)_                                                                                    |
| **Supported Languages**      | `Python`, `TypeScript`, `Go`, `Java`, `Rust`, `C#`                                                                                                                       |
| **Primary AI Traps**         | Writing buggy per-category heuristics for Wild Joker (`0`) instead of exact combinatorial delegation ($6^k$) · Scoring 5-of-a-kind `[4,4,4,4,4]` as a valid `full_house` |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/emilybache/Yatzy-Refactoring-Kata.git yatzy-interview
cd yatzy-interview/python # (or typescript / go / java / rust / csharp)
rm -rf ../.git && git init && git add . && git commit -m "Initial interview baseline"
pytest
```

### Seeded Defects to Inject Before the Session

1. **Bug 1 (Strict `full_house` & `two_pair` Distinct Face Rule)**: In strict Yatzy rules, `full_house` requires a three-of-a-kind of one face and a pair of a **different** face (so `[4, 4, 4, 4, 4]` scores `0` in `full_house`, and `[3, 3, 3, 3, 1]` scores `0` in `two_pair`!). Seed a bug where `[4, 4, 4, 4, 4]` returns `20` in `full_house` or `12` in `two_pair`.
2. **Commented Tests**: Comment out `test_full_house_rejects_five_of_a_kind`, `test_two_pair_rejects_four_of_a_kind`, and `test_score_with_joker` in `test_yatzy.py`.

---

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
>
> You are working on the Yatzy dice scoring engine (`Yatzy-Refactoring-Kata`). You have full access to the AI Assistant and `pytest`.
>
> ### Problem Context
>
> 1. **Fix Existing Strict Category Bugs (`full_house` & `two_pair`)**:
>    - In strict Scandinavian Yatzy:
>      - **`two_pair`**: Requires two **distinct** pairs of different die faces (e.g., `[3, 3, 5, 5, 1]` → `3+3+5+5 = 16`). Four of the same face (`[3, 3, 3, 3, 1]`) is **NOT** two pairs and must score **`0`**!
>      - **`full_house`**: Requires `3` of one face and `2` of a **different** face (e.g., `[2, 2, 3, 3, 3]` → `13`). Five of the same face (`[4, 4, 4, 4, 4]`) is **NOT** a full house and must score **`0`**!
> 2. **New Feature — Wild Joker Dice (`score_with_joker(dice, category_fn)`)**:
>    - Implement `score_with_joker(dice: list[int], category_fn: Callable)`:
>      - Each die in the 5-dice list is either a standard face (`1..6`) or **`0` (a Wild Joker)**.
>      - Each `0` Joker independently transforms into whatever standard die face (`1..6`) **maximizes** the score of `category_fn` for that 5-dice roll!
>      - Examples:
>        - `score_with_joker([0, 2, 3, 4, 5], Yatzy.small_straight)` → Joker becomes `1` → scores `15`.
>        - `score_with_joker([0, 0, 4, 4, 4], Yatzy.full_house)` → Both jokers become `6` (`[6, 6, 4, 4, 4]`, NOT `4` because `[4, 4, 4, 4, 4]` scores `0` in strict `full_house`!) → scores `6+6+4+4+4 = 24`.
>
> ### Your Tasks
>
> 1. **Explore & Run Tests**: Read `yatzy.py` and `test_yatzy.py`. Run `pytest`.
> 2. **Uncomment & Fix Strict `full_house` / `two_pair` Bugs**: Uncomment the disabled tests and fix `full_house` and `two_pair`.
> 3. **Refactor & Implement `score_with_joker`**: Clean up the category scorers and implement `score_with_joker`.
> 4. **Verify Edge Cases**: Test `[0, 0, 4, 4, 4]` on `full_house` (must return `24`, not `0` or `20`!), `[0, 3, 3, 3, 1]` on `two_pair` (joker becomes `1` → `[1, 3, 3, 3, 1]` → `3+3+1+1 = 8`), and 5 jokers `[0, 0, 0, 0, 0]`.

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Letting AI Write Custom Greedy Heuristics for `score_with_joker`

- **What Naive AI Writes**:
  - When asked to implement `score_with_joker`, LLMs often try to write "clever" greedy rules (e.g., _"replace `0` with the most frequent die face in `dice`, or `6` if tied"_).
- **Why It Fails Miserably**:
  1. On `score_with_joker([0, 0, 4, 4, 4], Yatzy.full_house)`, replacing `0` with the most frequent face (`4`) yields `[4, 4, 4, 4, 4]`, which scores **`0`** in strict `full_house` (instead of `[6, 6, 4, 4, 4] -> 24`)!
  2. On `score_with_joker([0, 2, 3, 4, 5], Yatzy.small_straight)`, replacing `0` with `6` yields `[6, 2, 3, 4, 5]` (Large Straight = `0` points in `small_straight`!), whereas replacing `0` with `1` scores `15`!
- **The Brilliant Architectural Solution ($6^k$ Combinatorial Delegation)**:
  - There are only 5 dice! Even if all 5 dice are jokers (`k = 5`), $6^5 = 7,776$ combinations (and for 1–2 jokers, only `6` or `36` combinations!).
  - Simply expand each `0` across `(1, 2, 3, 4, 5, 6)` using `itertools.product` and return `max(category_fn(*candidate) for candidate in candidates)`! It is **8 lines of code**, runs in `< 2ms`, and is **100% mathematically guaranteed optimal** across every category!

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Inspect `yatzy.py` and explain how `two_pair` and `full_house` currently count tallies."_
2. **Step 2 (`Plan`)**:
   - Fix `two_pair` (require `len(pairs) == 2` distinct faces with count `>= 2`, where `count >= 4` of a single face only counts as 1 pair!) and `full_house` (require exact counts `2` and `3` of distinct faces).
   - Implement `score_with_joker` by substituting `[1..6]` for each `0` via `itertools.product` and taking `max(category_fn(*roll))`.
3. **Step 3 (`Prompt`)** & **Step 4 (`Review`)**:
   - Prompt both steps cleanly and verify `[0, 0, 4, 4, 4]` on `full_house` returns `24`.

---

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

|   #   | Criterion                        | Strong Hire / Hire (`Score 3–4`)                                                                                                                      | No Hire / Blind Vibe-Coder (`Score 1–2`)                                                    |
| :---: | :------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------ |
| **1** | **Problem Decomposition**        | Recognizes that `score_with_joker` can delegate directly to the pure category functions via Cartesian product ($6^k$).                                | Tries to modify all 15 category functions to accept `0` jokers individually!                |
| **2** | **Prompt Context Quality**       | Instructs AI to use `itertools.product` over `1..6` for joker slots rather than per-category heuristics.                                              | Prompts _"Implement `score_with_joker`"_, getting broken greedy heuristics.                 |
| **3** | **Not Blindly Trusting AI**      | Rejects greedy joker replacement by testing `[0, 0, 4, 4, 4]` on `full_house` and `[0, 2, 3, 4, 5]` on `small_straight`.                              | Accepts greedy joker replacement without testing `full_house` or `small_straight`.          |
| **4** | **Code Reading Speed**           | Quickly spots the 1-indexed vs 0-indexed `tallies` array smells in legacy `yatzy.py`.                                                                 | Gets confused by `tallies[i]` off-by-one indexing in `yatzy.py`.                            |
| **5** | **Bug & Edge-Case Discovery**    | Tests `[4,4,4,4,4]` on `full_house` (`0`), `[3,3,3,3,1]` on `two_pair` (`0`), and `[0,0,4,4,4]` on `full_house` (`24`).                               | Allows `[3,3,3,3,1]` to score `12` in `two_pair`.                                           |
| **6** | **Testing Before Claiming Done** | Uncomments all tests and runs `pytest` after every change.                                                                                            | Claims done without testing `score_with_joker` on `full_house`.                             |
| **7** | **Explaining Correctness**       | Explains why $6^k$ exhaustive search for $k \le 5$ ($7,776$ max states) is superior in both correctness and maintainability to 15 bespoke heuristics. | Cannot explain why greedy mode fails on `full_house` when `3` of a kind is already present. |

### Interviewer Probing Questions (Final 10 Minutes)

1. **Q**: _"What is the worst-case number of evaluations of `category_fn` in your `score_with_joker` when a roll has `k` jokers, and why is exhaustive search the right engineering trade-off here?"_  
   **Expected Answer**: $6^k$ evaluations, which is at most $6^2 = 36$ for 2 jokers and $6^5 = 7,776$ if all 5 dice are jokers (`< 2ms` in Python). It decouples joker expansion from category rules, guaranteeing zero bugs if new categories are added later.
