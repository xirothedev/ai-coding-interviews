# E05 — Lift Pass Dynamic Pricing & Holiday Blackout Calendar

> 🌐 Ngôn ngữ: <a href="E05-lift-pass-pricing">English</a> · **Tiếng Việt**

[⬅️ Back to Easy Catalog](README.md) · [🏠 Master Hub](../../../README.md)

| Attribute                    | Details                                                                                                                                   |
| :--------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------- |
| **Case ID**                  | `E05`                                                                                                                                     |
| **Difficulty Level**         | 🟢 **Easy** (`30–45 mins` — Junior / Mid Bar)                                                                                             |
| **Task Archetype**           | Legacy Refactoring + Feature Extension                                                                                                    |
| **Source GitHub Repository** | [`martinsson/Refactoring-Kata-Lift-Pass-Pricing`](https://github.com/martinsson/Refactoring-Kata-Lift-Pass-Pricing)                       |
| **Target Files**             | `src/prices.py` & `test/test_prices.py` _(or `typescript/`, `java/`, `csharp/`, `scala/`, `php/`)_                                        |
| **Supported Languages**      | `Python`, `TypeScript`, `Java`, `C#`                                                                                                      |
| **Primary AI Traps**         | Counting free toddlers (`age < 6`) toward the `4+` paying group discount threshold · Applying `math.ceil` in the wrong intermediate order |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/martinsson/Refactoring-Kata-Lift-Pass-Pricing.git lift-pass-interview
cd lift-pass-interview/python # (or typescript / java / csharp)
rm -rf ../.git && git init && git add . && git commit -m "Initial interview baseline"
PYTHONPATH=src pytest
```

### Seeded Defects to Inject Before the Session

1. **Bug 1 (Age Bracket Boundary Bug)**: In `src/prices.py`, seed an off-by-one boundary on `age < 6` (`<= 6`) or `age > 64` (`>= 64`) for `night` vs `1jour` passes.
2. **Commented Tests**: Comment out `test_exact_age_6_and_64_boundaries` and `test_group_discount_excludes_free_children` in `test/test_prices.py`.

---

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
>
> You are working on the dynamic lift-pass pricing service for a ski resort. You have full access to the AI Assistant and the test suite.
>
> ### What We Need You to Do
>
> 1. **Fix the Age Bracket Boundary Defect**:
>    - Our pricing rules by age bracket are:
>      - Children strictly under 6 (`age < 6`): always `0` cost (for both `1jour` day passes and `night` passes).
>      - Youth (`6 <= age < 15`): `1jour` is `70%` of the base price (`ceil(base * 0.7)`), while `night` is `0`.
>      - Adults (`15 <= age <= 64`): `1jour` is `100%` of the base price, while `night` is `$19`.
>      - Seniors (`age > 64`): `1jour` is `75%` of the base price (`ceil(base * 0.75)`), while `night` is `40%` of `$19` (`ceil(19 * 0.4) = $8`).
>      - On non-holiday Mondays, `1jour` passes for ages `>= 15` receive a `35%` Monday discount (`* 0.65`).
>    - Right now, exact boundary ages (`6` and `64`) are being misclassified.
> 2. **Add Group Checkout Pricing**:
>    - We need a pure pricing function that computes the total cost for a group of skiers given their list of `ages`.
>    - **Group Discount Rule**: When a group has **`4 or more PAYING skiers`** (meaning skiers whose individual ticket price before the group discount is **strictly greater than `0`**—so free children `< 6` on `1jour` and free youth `< 15` on `night` passes do **not** count toward the `4`-skier threshold), apply an additional `10%` group discount (`* 0.90`) on non-holiday dates, rounding each paying skier's ticket with `ceil()`.
>    - On holidays, both the Monday `35%` discount and the `10%` group discount are blacked out (disabled).
>
> Please explore the codebase, decouple pure pricing calculations from HTTP/database plumbing where helpful, re-enable any commented-out tests, fix the boundary bug, and implement `calculate_group_price` with full edge-case tests.

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
   > _"Do not write code. Extract a truth table of `pass_type` (`1jour` vs `night`), `age` brackets (`<6`, `6..14`, `15..64`, `>64`), and Monday/Holiday discounts from `src/prices.py`."_
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

2. **Q**: _"Why must free children under 6 be excluded from the group-discount count?"_
   **Expected Answer**: Otherwise a group of 3 paying adults plus free toddlers could wrongly trigger the 4+ paying discount.
