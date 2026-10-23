# E05 — Lift Pass Dynamic Pricing & Holiday Blackout Calendar

[⬅️ Back to Easy Catalog](README.md) · [🏠 Master Hub](../../README.md)

| Attribute                    | Details                                                                                                                                   |
| :--------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------- |
| **Case ID**                  | `E05`                                                                                                                                     |
| **Difficulty Level**         | 🟢 **Easy** (`30–45 mins` — Junior / Mid Bar)                                                                                             |
| **Task Archetype**           | Legacy Refactoring + Feature Extension                                                                                                    |
| **Source GitHub Repository** | [`emilybache/Lift-Pass-Pricing-Refactoring-Kata`](https://github.com/emilybache/Lift-Pass-Pricing-Refactoring-Kata)                       |
| **Target Files**             | `prices.py` & `test_prices.py` _(or `TypeScript/`, `go/`, `java/`, `csharp/`)_                                                            |
| **Supported Languages**      | `Python`, `TypeScript`, `Go`, `Java`, `C#`                                                                                                |
| **Primary AI Traps**         | Counting free toddlers (`age < 6`) toward the `4+` paying group discount threshold · Applying `math.ceil` in the wrong intermediate order |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/emilybache/Lift-Pass-Pricing-Refactoring-Kata.git lift-pass-interview
cd lift-pass-interview/python # (or typescript / go / java / csharp)
rm -rf ../.git && git init && git add . && git commit -m "Initial interview baseline"
pytest
```

### Seeded Defects to Inject Before the Session

1. **Bug 1 (Age Bracket Boundary Bug)**: In `prices.py`, seed an off-by-one boundary on `age < 6` (`<= 6`) or `age > 64` (`>= 64`) for `night` vs `1jour` passes.
2. **Commented Tests**: Comment out `test_exact_age_6_and_64_boundaries` and `test_group_discount_excludes_free_children` in `test_prices.py`.

---

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
>
> You are working on the dynamic pricing calculator for a ski resort (`Lift-Pass-Pricing-Refactoring-Kata`). You have full access to the AI Assistant and test suite.
>
> ### Problem Context
>
> 1. **Fix Existing Age Bracket Boundary Bug**:
>    - Children strictly under 6 (`age < 6`) are always `0` cost (for both `1jour` and `night` passes).
>    - Youth (`6 <= age < 15`): `1jour` is `70%` of base price (`math.ceil(base * 0.7)`), `night` is `0`.
>    - Adults (`15 <= age <= 64`): `1jour` is `100%` of base price, `night` is `$19`.
>    - Seniors (`age > 64`): `1jour` is `75%` of base price (`math.ceil(base * 0.75)`), `night` is `40%` of `$19` (`math.ceil(19 * 0.4) = $8`).
>    - On non-holiday Mondays, `1jour` passes for ages `>= 15` receive a `35%` Monday discount (`* 0.65`).
> 2. **New Feature — Group Checkout (`calculate_group_price(pass_type, base_price, ages, date_str, holidays)`)**:
>    - Calculate the total price for a group of skiers given their list of `ages: list[int]`.
>    - **Group Discount Rule**: If the group contains **`4 or more PAYING skiers`** (i.e., skiers whose individual pass price before group discount is **`> 0`**—so children `age < 6` on `1jour` and anyone `< 15` on `night` passes do **NOT** count toward the `4` paying skiers threshold!), apply an additional `10%` group discount (`* 0.90`) on non-holiday dates, rounding each paying skier's final ticket with `math.ceil()`!
>    - On holidays, the `10%` group discount (just like the Monday `35%` discount) is **blacked out (disabled)**.
>
> ### Your Tasks
>
> 1. **Explore & Trace**: Read `prices.py` and `test_prices.py` to understand the deeply nested legacy pricing rules.
> 2. **Run & Uncomment Tests**: Run `pytest` and uncomment the boundary and group-pricing tests.
> 3. **Fix Age Boundaries & Implement `calculate_group_price`**: Refactor the pure pricing logic from HTTP/DB concerns and implement `calculate_group_price`.
> 4. **Verify Edge Cases**: Test a group of `[30, 32, 4, 5]` (2 adults + 2 free 4/5-year-olds = only `2` paying skiers → NO group discount!), `[30, 32, 35, 10]` on a `night` pass (`10`-year-old is free at night → only `3` paying skiers → NO group discount!), and a non-holiday Monday with 4 paying adults.

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Checking `if len(ages) >= 4:` or `if sum(1 for a in ages if a >= 6) >= 4:`

- **What Naive AI Writes**:
  ```python
  has_group_discount = len([a for a in ages if a >= 6]) >= 4 and not is_holiday
  ```
- **Why It Fails**: What if `pass_type == "night"` and `ages = [30, 32, 35, 12]`? A `12`-year-old pays `$0` for a `"night"` pass (`age < 15` is free at night!). So there are only **3 paying skiers** (`30, 32, 35`), NOT 4! Checking `a >= 6` instead of `individual_price > 0` illegally grants the group discount on night passes!
- **Correct Fix**: Compute each skier's individual price (or `is_paying_skier(pass_type, age)`) first, and check `sum(1 for p in base_prices if p > 0) >= 4`!

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Extract a truth table of `pass_type` (`1jour` vs `night`), `age` brackets (`<6`, `6..14`, `15..64`, `>64`), and Monday/Holiday discounts from `prices.py`."_
2. **Step 2 (`Plan`)**:
   - Extract a pure `compute_single_ticket_price(pass_type, base_price, age, is_monday, is_holiday)` function; define paying skiers as those with `single_price > 0`; apply the group multiplier when `paying_count >= 4 and not is_holiday`.
3. **Step 3 (`Prompt`)** & **Step 4 (`Review`)**:
   - Audit how `night` passes for `6 <= age < 15` (`price == 0`) are counted toward `paying_count`.

---

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

|   #   | Criterion                        | Strong Hire / Hire (`Score 3–4`)                                                                                         | No Hire / Blind Vibe-Coder (`Score 1–2`)                                                     |
| :---: | :------------------------------- | :----------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------- |
| **1** | **Problem Decomposition**        | Extracts pure single-ticket pricing first, then builds `calculate_group_price` on top of it.                             | Leaves pricing entangled with HTTP query strings and database calls.                         |
| **2** | **Prompt Context Quality**       | Specifies that "paying skier" means `ticket_price > 0` (which excludes `age < 6` on `1jour` AND `age < 15` on `night`).  | Prompts _"Add 10% group discount if 4 or more people"_.                                      |
| **3** | **Not Blindly Trusting AI**      | Catches AI checking `len(ages) >= 4` or `age >= 6` instead of `price > 0` for `night` passes.                            | Accepts `len(ages) >= 4`, allowing 1 adult + 3 toddlers to get the discount.                 |
| **4** | **Code Reading Speed**           | Untangles the legacy nested `if/else` tree in `prices.py` within 8 minutes.                                              | Gets confused by the negated `if not is_holiday:` branches in legacy code.                   |
| **5** | **Bug & Edge-Case Discovery**    | Tests `age = 6`, `age = 15`, `age = 64`, `night` pass with 3 adults + 1 12-year-old, and holiday Monday.                 | Misses the `night` pass `6 <= age < 15` free-ticket rule when counting paying group members. |
| **6** | **Testing Before Claiming Done** | Runs `pytest` after extracting pure functions and tests all age/pass-type combinations.                                  | Claims done without testing `night` group passes.                                            |
| **7** | **Explaining Correctness**       | Explains Humble Object / Functional Core pattern (separating pure pricing math from I/O) and `math.ceil` rounding order. | Cannot explain what happens on a Monday that is also a public holiday.                       |

### Interviewer Probing Questions (Final 10 Minutes)

1. **Q**: _"In a group of three 30-year-olds and one 10-year-old buying a `'night'` pass, how many paying skiers are there, and does the group discount apply?"_  
   **Expected Answer**: Only `3` paying skiers, because youth (`age < 15`) are free (`$0`) for `'night'` passes. Therefore, the `4+` paying skiers threshold is not met and no group discount applies.
