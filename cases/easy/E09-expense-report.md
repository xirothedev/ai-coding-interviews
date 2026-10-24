# E09 — Expense Report Meal Cap Auditor & Multi-Currency Conversion

[⬅️ Back to Easy Catalog](README.md) · [🏠 Master Hub](../../README.md)

| Attribute                    | Details                                                                                                                                                                                                        |
| :--------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Case ID**                  | `E09`                                                                                                                                                                                                          |
| **Difficulty Level**         | 🟢 **Easy** (`30–45 mins` — Junior / Mid Bar)                                                                                                                                                                  |
| **Task Archetype**           | Legacy Refactoring + Feature Extension                                                                                                                                                                         |
| **Source GitHub Repository** | [`emilybache/ExpenseReport-Refactoring-Kata`](https://github.com/emilybache/ExpenseReport-Refactoring-Kata)                                                                                                    |
| **Target Files**             | `expense_report.py` & `test/test_expense_report.py` _(in `expensereport-python/`, or `expensereport-typescript/`, `expensereport-go/`, `expensereport-java/`, `expensereport-rust/`, `expensereport-csharp/`)_ |
| **Supported Languages**      | `Python`, `TypeScript`, `Go`, `Java`, `Rust`, `C#`                                                                                                                                                             |
| **Primary AI Traps**         | Checking meal over-limit threshold (`> 5000`) _before_ currency conversion (flagging `3000 JPY` as over `$50`!) · Unrounded float sum disagreeing with printed line items                                      |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/emilybache/ExpenseReport-Refactoring-Kata.git expense-interview
cd expense-interview/expensereport-python # (or expensereport-typescript / expensereport-go / expensereport-java / expensereport-rust / expensereport-csharp)
rm -rf ../.git && git init && git add . && git commit -m "Initial interview baseline"
pytest
```

### Seeded Defects to Inject Before the Session

1. **Bug 1 (Meal Cap Boundary Off-by-One)**: In `expense_report.py`, seed `expense.amount >= 5000` instead of `> 5000` for `DINNER` (or `>= 1000` instead of `> 1000` for `BREAKFAST`), so an exact `5000` dinner is falsely flagged with `"X"`.
2. **Commented Tests**: Comment out `test_exact_cap_boundary`, `test_lunch_cap_and_subtotal`, and `test_multi_currency_conversion_and_rounding` in `test/test_expense_report.py`.

---

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
>
> You are working on our employee Expense Report generator and policy auditor. You have full access to the AI Assistant and the unit test suite.
>
> ### What We Need You to Do
>
> 1. **Fix Meal Cap Boundaries & Add `LUNCH` Expense Support**:
>    - Our meal over-expense marker (`"X"` vs `" "`) rules in base USD are:
>      - `BREAKFAST`: counts as a Meal; flagged `"X"` only when base USD amount is **strictly `> 1000`**.
>      - `LUNCH` (New!): counts as a Meal; flagged `"X"` only when base USD amount is **strictly `> 2000`**.
>      - `DINNER`: counts as a Meal; flagged `"X"` only when base USD amount is **strictly `> 5000`**.
>      - `CAR_RENTAL`: not a meal expense and never flagged `"X"`.
> 2. **Support Multi-Currency Conversion (`currency: str = "USD"`, `exchange_rates: dict[str, Decimal | float]`)**:
>    - Allow each `Expense` to carry an optional `currency: str = "USD"` (defaulting to `"USD"` with rate `1.0`), and accept an optional `exchange_rates` mapping when printing the report.
>    - Convert each expense amount into base USD integer units using **Banker's Rounding (`ROUND_HALF_EVEN`)** _per line item_.
>    - **Accounting Invariants**:
>      - **Invariant 1**: The over-limit marker `"X"` must be evaluated against the **converted base USD `converted_amount`**, never the raw foreign-currency integer (for example, a `DINNER` of `6000 JPY` at rate `0.0067` converts to `40 USD <= 5000`, so it must **not** be flagged `"X"`).
>      - **Invariant 2**: Both `"Meals:"` and `"Total:"` summary lines must equal the exact sum of the **rounded line-item `converted_amount` values** printed on the report (never sum unrounded floats and round at the end).
>      - Unknown currency codes must raise a `ValueError("Unsupported currency: ...")`.
>
> Please explore the codebase, re-enable any commented-out tests, fix the boundary check, implement `LUNCH` and multi-currency conversion, and verify all accounting invariants with unit tests.

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Evaluating `is_over_limit()` on `expense.amount` Before Currency Conversion

- **What Naive AI Writes**:
  ```python
  class Expense:
      def is_over_limit(self) -> bool:
          return (self.type == ExpenseType.DINNER and self.amount > 5000) ...
  ```
- **Why It Fails**: Because `Expense` doesn't know the `exchange_rates` table passed to `print_report(expenses, exchange_rates)`, an LLM that puts `is_over_limit()` as a zero-arg method on `Expense` evaluates `self.amount > 5000` in raw foreign currency (`6000 JPY > 5000 -> True`)!
- **Correct Fix**: Pass `converted_usd_amount` to `is_over_limit(converted_usd_amount)` (or compute `LineItem(name, converted_amount, is_meal, is_over_limit)` after converting `expense.amount` to USD).

### Trap 2: Summing Unrounded Floats for `total` While Printing Rounded Line Items

- **Why It Fails**: Suppose three `LUNCH` items convert to `100.4`, `100.4`, and `100.4`. Each line item prints as `100`. If `total` sums the raw floats (`301.2 -> 301`), the report prints three lines of `100` and a total of `301` (`100 + 100 + 100 != 301`)!

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Trace `print_report` in `expense_report.py` and list the exact output format and rules for each `ExpenseType`."_
2. **Step 2 (`Plan`)**:
   - Define a table/enum mapping `ExpenseType -> (display_name, is_meal, limit_usd)`; convert each `Expense` first via `converted = int(Decimal(str(amount)) * Decimal(str(rate))).quantize(1, ROUND_HALF_EVEN)`; evaluate `is_over_limit` and accumulate `meal_expenses` and `total` using `converted`.
3. **Step 3 (`Prompt`)** & **Step 4 (`Review`)**:
   - Verify `is_over_limit` checks `converted` (not `expense.amount`) and sums use `converted`.

---

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

|   #   | Criterion                        | Strong Hire / Hire (`Score 3–4`)                                                                                                                 | No Hire / Blind Vibe-Coder (`Score 1–2`)                                                |
| :---: | :------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------- |
| **1** | **Problem Decomposition**        | Separates currency normalization (`Expense -> NormalizedLineItem`) from policy rules and report formatting.                                      | Mixes currency math, string formatting, and type checks in a single loop.               |
| **2** | **Prompt Context Quality**       | Explicitly specifies converting to integer USD _first_ with `ROUND_HALF_EVEN` and using the converted integer for both cap checks and subtotals. | Prompts _"Add currency conversion and LUNCH to `expense_report.py`"_.                   |
| **3** | **Not Blindly Trusting AI**      | Audits whether `is_over_limit` uses `converted_amount` vs `expense.amount`.                                                                      | Accepts AI's `expense.is_over_limit()` method that checks raw `JPY` against USD limits! |
| **4** | **Code Reading Speed**           | Reads the entire `expense_report` file and test suite in `< 5 minutes`.                                                                          | Misses the tab/space formatting contract in `print_report`.                             |
| **5** | **Bug & Edge-Case Discovery**    | Tests `6000 JPY` (`< $50` USD), `60 EUR` (`> $10` USD), exact limit `5000`, and `3 x 100.4` rounding sum consistency.                            | Only tests `USD` (`rate = 1.0`) for over-limit markers.                                 |
| **6** | **Testing Before Claiming Done** | Uncomments all tests and adds multi-currency over-limit and rounding-sum tests.                                                                  | Claims done without testing foreign currency over-limit thresholds.                     |
| **7** | **Explaining Correctness**       | Explains why financial reports must sum already-rounded line items so columns always reconcile visually and mathematically.                      | Cannot explain why summing raw floats before rounding breaks accounting reconciliation. |

### Interviewer Probing Questions (Final 10 Minutes)

1. **Q**: _"If three line items convert to `$10.004`, `$10.004`, and `$10.004`, why must the printed Total be `$30.00` instead of `round(30.012, 2) = $30.01`?"_  
   **Expected Answer**: In financial invoices and expense reports, each line item is rounded to minor currency units (`$10.00`) when recorded. If the printed line items are `$10.00`, `$10.00`, and `$10.00`, printing a Total of `$30.01` violates column addition reconciliation (`sum(printed_lines) == printed_total`).

2. **Q**: _"Why convert and round each line item before summing, instead of summing raw floats?"_
   **Expected Answer**: Summing unrounded floats accumulates representation error; per-item rounding keeps the printed total consistent.
