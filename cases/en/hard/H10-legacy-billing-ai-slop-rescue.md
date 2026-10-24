# H10 — Multi-Language Legacy Billing & Rule Engine ("AI-Slop" Rescue)

[⬅️ Back to Hard Catalog](README.md) · [🏠 Master Hub](../../../README.md)

| Attribute                      | Details                                                                                                                                                                                                                                                                                 |
| :----------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Case ID**                    | `H10`                                                                                                                                                                                                                                                                                   |
| **Difficulty Level**           | 🔴 **Hard** (`60–75 mins` — Senior / Staff Capstone)                                                                                                                                                                                                                                    |
| **Task Archetype**             | Code Review & AI Hallucination Rescue ("AI-Slop" PR Rescue)                                                                                                                                                                                                                             |
| **Source GitHub Repositories** | [`stripe-samples/subscription-use-cases`](https://github.com/stripe-samples/subscription-use-cases) · [`getlago/lago`](https://github.com/getlago/lago) · [`killbill/killbill`](https://github.com/killbill/killbill)                                                                   |
| **Target Files**               | Billing/Subscription/Invoice calculator & test suite in chosen language directory (`server/python`, `server/node`, `server/go`, `server/java`, `server/dotnet` in `stripe-samples/subscription-use-cases`, `events-processor/` in `getlago/lago`, or `invoice/` in `killbill/killbill`) |
| **Supported Languages**        | **Polyglot**: `Python`, `TypeScript`, `Go`, `Java`, `Rust`, `C#`                                                                                                                                                                                                                        |
| **Hard Taxonomy Pillars**      | Pillar 1 (Mutated Shared Rate Cache) · Pillar 3 (Accounting Invariants) · Pillar 5 (AI-Slop Hallucination Rescue)                                                                                                                                                                       |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Source Repository & Pull Request (Confidential)

| Field                              | Value                                      |
| :--------------------------------- | :----------------------------------------- |
| **Repository**                     | `https://github.com/getlago/lago`          |
| **Base SHA (pre-merge)**           | `4fae86e578f565907c2e6082856b460b2bfac0a8` |
| **Merge SHA (reference solution)** | `878c66c1f01d6831016d340674b6e68c2138ccc3` |
| **Test Command**                   | `make test`                                |

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/getlago/lago.git interview-workspace
cd interview-workspace
git checkout 4fae86e578f565907c2e6082856b460b2bfac0a8
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
make test
```

### Reproducibility Verification

- **Base SHA (`4fae86e578f5`)**: the test suite must contain at least one failing test related to the issue.
- **Merge SHA (`878c66c1f01d`)**: the same tests must pass after checkout.

### Files Changed (Reference Solution)

- .github/workflows/release-docker-image.yml

### Failing Tests to Enable

- Re-enable any commented-out or skipped tests covering the issue; run `make test` to confirm red on Base SHA and green on Merge SHA.

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
>
> You are reviewing and rescuing a critical billing & cost-allocation module that a previous engineer generated with heavy AI assistance. The test suite currently passes, **but Finance reported severe accounting discrepancies in production**.
>
> ### Domain Specification & Accounting Invariants
>
> 1. **Stateless Execution Across Calls**: Processing a VIP, promotional, or tax-exempt customer invoice MUST NEVER mutate shared configuration or affect subsequent invoices in the same process.
> 2. **Canonical Discount Precedence & Zero Floor**:
>    - Regardless of the order discounts are passed in the input list, discounts MUST be applied in strict canonical order:
>      1. **Line-Item Volume/Bundle Discounts** first
>      2. **Percentage (`%`) Cart Discounts** second
>      3. **Flat-Amount (`$`) Vouchers** third
>    - Net taxable subtotal is floored at **`0` cents** (a `$100` voucher on a `$60` order results in `$0.00` taxable subtotal and `$0.00` tax—never negative tax!).
> 3. **Strict Tax Jurisdiction Validation**: Unknown or expired tax jurisdiction codes must raise an explicit `InvalidTaxJurisdictionError` (never silently default to `0%` inside a broad `try/catch`).
> 4. **Penny-Exact Installment & Cost-Center Allocation (Largest Remainder / Hamilton's Method)**:
>    - All money math must operate in integer minor units (cents) using Banker's Rounding (`ROUND_HALF_EVEN`).
>    - When splitting an invoice of `T` cents across `N` equal installments (where `T = q * N + r`, `0 <= r < N`), the first `r` installments receive `q + 1` cents and the remaining `N - r` installments receive `q` cents (e.g., `$100.00` split `6` ways → `[$16.67, $16.67, $16.67, $16.67, $16.66, $16.66]`, and `sum(installments) == T` ALWAYS holds).
>    - For weighted splits (`weights = [w_1, ..., w_N]`), allocate `floor(T * w_i / sum(W))` first, then distribute the remaining `r` single cents one by one to the entries with the **largest fractional remainders** (breaking ties by earlier index).
>
> ### Your Tasks
>
> 1. **Audit Code & Tests**: Inspect both the implementation and the existing unit tests. Identify why the tests are currently green despite the production bugs.
> 2. **Write Real Failing Regression Tests First**: Replace the tautological/over-mocked tests with concrete assertions that reproduce all 4 production defects.
> 3. **Refactor & Fix the Billing Engine**: Fix all 4 defects cleanly while preserving public API compatibility.
> 4. **Prove the Accounting Invariant**: Add a property/randomized test running 200+ carts and split configurations verifying `sum(installments) == total_cents` and zero cross-call state leakage.

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Asking AI "Are the Tests Passing?" Instead of Reading the Test Assertions

- **Why It Traps Blind Vibe-Coders**: A candidate who runs `pytest` / `npm test` at Minute 2 sees `5 passed in 0.03s` and assumes the existing behavior is tested! Even if they ask AI _"Review `billing.py` for bugs"_, the LLM rarely inspects the test file to point out that `mock_calculate.return_value = 1000` mocked out the entire engine under test!

### Trap 2: Dumping All Remainder Cents onto the Last Installment (`installments[-1] += remainder`)

- **What Naive AI Writes**:
  ```python
  base = total_cents // n
  installments = [base] * n
  installments[-1] += total_cents - (base * n) # <-- WRONG for n = 6, total = 10000!
  ```
- **Why It Fails**: For `total_cents = 10000` (`$100.00`) and `n = 6`, `10000 // 6 = 1666` with remainder `4`. Dumping `+4` on `installments[-1]` yields `[1666, 1666, 1666, 1666, 1666, 1670]`—a `4-cent` jump on the last payment instead of `1-cent` distributed to each of the first `r = 4` payments (`[1667, 1667, 1667, 1667, 1666, 1666]`)!
- **Correct Fix (Hamilton's / Largest Remainder Method)**:
  ```python
  # For weighted splits w_0 .. w_{n-1}:
  total_weight = sum(weights)
  exact_ numerators = [total_cents * w for w in weights]
  quotients = [num // total_weight for num in exact_numerators]
  remainders = [num % total_weight for num in exact_numerators]
  shortfall = total_cents - sum(quotients)
  # Sort indices by descending remainder, tie-breaking by ascending index i:
  ranked_indices = sorted(range(len(weights)), key=lambda i: (-remainders[i], i))
  for idx in ranked_indices[:shortfall]:
      quotients[idx] += 1
  ```

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Read both `billing` and `test_billing`. List: (1) every place where a module-level dictionary/list is mutated, (2) every `try/except` block that swallows errors, and (3) every unit test in `test_billing` that uses mocks or weak assertions."_
2. **Step 2 (`Plan`)**:
   - Candidate writes down the 4 bugs and writes failing unit tests for each bug _before_ changing the engine.
3. **Step 3 (`Prompt`)**:
   - Prompt 1: Replace shared mutable rate lookup with an immutable copy/lookup and strict `InvalidTaxJurisdictionError`.
   - Prompt 2: Implement canonical discount sorting (`BUNDLE -> PERCENT -> FLAT`) and `max(0, subtotal_cents)` clamping.
   - Prompt 3: Implement Hamilton's Largest Remainder Method using exact integer numerator arithmetic (`(total_cents * w) % total_weight`) to avoid floating-point remainder ties!
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Audit the weighted split for float vs integer remainder comparison (`num % total_weight` is exact; `(total_cents * w / total_weight) % 1` suffers from float inaccuracy!).

---

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

|   #   | Criterion                        | Strong Hire / Hire (`Score 3–4`)                                                                                                      | No Hire / Blind Vibe-Coder (`Score 1–2`)                                                                       |
| :---: | :------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------ | :------------------------------------------------------------------------------------------------------------- |
| **1** | **Problem Decomposition**        | Audits tests first, writes failing regression tests for all 4 bugs, then fixes each stage of the pipeline sequentially.               | Asks AI to "rewrite the whole billing file to fix bugs" in one shot.                                           |
| **2** | **Prompt Context Quality**       | Specifies integer modulo arithmetic `(total_cents * w) % total_weight` for Hamilton's Method and canonical discount ordering.         | Prompts _"Split total across installments without losing pennies"_, getting the `installments[-1] += rem` bug. |
| **3** | **Not Blindly Trusting AI**      | Spots the mocked-out tests in the starter repo AND catches float-remainder bugs in AI's weighted split implementation.                | Trusts the initial green test suite or accepts `installments[-1] += remainder`.                                |
| **4** | **Code Reading Speed**           | Identifies all 4 seeded AI-slop bugs and the fake unit tests within 10–12 minutes.                                                    | Spends 25 minutes reading docstrings without noticing `DEFAULT_RATES` is mutated in-place.                     |
| **5** | **Bug & Edge-Case Discovery**    | Tests VIP call followed by Standard call, `voucher > subtotal`, `$100 / 6` split, and weighted `[1, 1, 1]` split.                     | Only tests a single customer call in isolation (missing the cross-call mutation leak!).                        |
| **6** | **Testing Before Claiming Done** | Writes TDD failing tests _before_ fixing the code, plus a 200-iteration randomized invariant test at the end.                         | Modifies production code without fixing the broken mock tests.                                                 |
| **7** | **Explaining Correctness**       | Explains why integer remainder `(T * w_i) % sum(W)` is mathematically exact without IEEE-754 float error, and proves `shortfall < N`. | Cannot prove why `shortfall = T - sum(floor_quotients)` is always strictly less than `N`.                      |

### Interviewer Probing Questions (Final 10 Minutes)

1. **Q**: _"In weighted installment splitting, why is ranking remainders using integer modulo `(total_cents * w_i) % total_weight` better than `float_share - math.floor(float_share)`?"_  
   **Expected Answer**: Floating-point division (`10000 * 1 / 3.0`) introduces binary representation rounding error, which can cause two identical weights to have slightly different float remainders or flip tie-breaking order. `(total_cents * w_i) % total_weight` uses exact integer arithmetic.
2. **Q**: _"How do you know `shortfall = total_cents - sum(quotients)` is always strictly less than `N` (the number of installments)?"_  
   **Expected Answer**: Each of the `N` terms loses a fractional part strictly less than `1` (`r_i / W < 1`). Summing `N` terms each `< 1` yields a total shortfall strictly less than `N`, and since `shortfall` is an integer, `0 <= shortfall <= N - 1`.
