# E02 — Supermarket Receipt Discount Stacking & Bundle Rounding

[⬅️ Back to Easy Catalog](README.md) · [🏠 Master Hub](../../README.md)

| Attribute                    | Details                                                                                                                                                             |
| :--------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Case ID**                  | `E02`                                                                                                                                                               |
| **Difficulty Level**         | 🟢 **Easy** (`30–45 mins` — Junior / Mid Bar)                                                                                                                       |
| **Task Archetype**           | Bugfix + Feature Extension                                                                                                                                          |
| **Source GitHub Repository** | [`emilybache/SupermarketReceipt-Refactoring-Kata`](https://github.com/emilybache/SupermarketReceipt-Refactoring-Kata)                                               |
| **Target Files**             | `shopping_cart.py`, `teller.py`, `receipt.py`, `model_objects.py`, `tests/test_supermarket.py` _(or `typescript/`, `go/`, `java/`, `csharp/`)_                      |
| **Supported Languages**      | `Python`, `TypeScript`, `Go`, `Java`, `C#`                                                                                                                          |
| **Primary AI Traps**         | Partial bundle remainder bug (`7` items on `5-for-X`) · Evaluating minimum-spend coupon against gross pre-bundle total instead of net total · Float precision drift |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/emilybache/SupermarketReceipt-Refactoring-Kata.git supermarket-interview
cd supermarket-interview/python # (or typescript / go / java / csharp)
rm -rf ../.git && git init && git add . && git commit -m "Initial interview baseline"
pytest
```

### Seeded Defects to Inject Before the Session

1. **Bug 1 (Multi-Bundle Remainder Calculation in `ShoppingCart.handle_offers`)**: Note that in `python/shopping_cart.py` line 39, `SpecialOfferType.TWO_FOR_AMOUNT` **already has a live float-division bug** (`total = offer.argument * (quantity_as_int / x) + quantity_as_int % 2 * unit_price`, using float `/` instead of integer `//`!), and `FIVE_FOR_AMOUNT` vs `TWO_FOR_AMOUNT` have inconsistent bundle math. Seed or highlight the multi-bundle calculation bug (e.g., `int(quantity) // 5` without multiplying the bundle price by `number_of_xs`, or `TWO_FOR_AMOUNT` charging float-divided bundle prices on odd quantities like `3` or `5` items!).
2. **Commented Tests**: Comment out `test_ten_items_on_five_for_amount_offer` and `test_coupon_threshold_after_bundle_discounts` in `tests/test_supermarket.py`.

---

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
>
> You are working on our supermarket checkout and receipt calculation engine. You have full access to the AI Assistant and the unit test suite.
>
> ### What We Need You to Do
>
> 1. **Fix the Multi-Bundle Offer Overcharge Bug**:
>    - Store managers reported that customers buying multiple bundles or odd quantities on bundle offers (such as `2-for-$A` or `5-for-$A`, potentially scanned across multiple separate additions to the cart) are being charged the wrong total.
>    - For any total quantity `Q` of a product on an `N-for-$A` offer (with unit price `P`): the number of full bundles is `int(Q) // N` and the remaining unbundled units are `Q - (bundles * N)`. The net cost for that product must equal `bundles * A + remainder * P`.
> 2. **Add Cart-Level Minimum-Spend Loyalty Coupons**:
>    - We want to support a cart-level loyalty coupon defined by `(threshold_amount, discount_amount)`:
>      - The `threshold_amount` **must be evaluated against the net cart subtotal AFTER all product-level special offers (`ThreeForTwo`, `TwoForAmount`, `FiveForAmount`, `TenPercentDiscount`) have already been deducted**—never against the gross pre-discount subtotal.
>      - For example, if gross items total `$52.00` and bundle discounts subtract `$5.00`, the net subtotal is `$47.00`, so a `"$10 off $50+"` coupon must **not** apply (`$47.00 < $50.00`).
>      - Ensure floating-point representation drift (such as `3 * 19.99 - 9.97` evaluating to `49.99999999999999`) does not block an exact `$50.00` net cart, and ensure the final receipt total is rounded to 2 decimal places and never drops below `0.00`.
>
> Please explore the codebase, re-enable any commented-out tests in the test suite, fix the bundle pricing bug, implement the loyalty coupon rule, and add tests covering multi-scan bundles and exact threshold boundaries.

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Checking Coupon Threshold Against `receipt.total_price()` Before Offers Are Applied

- **What Naive AI Writes**:
  - Evaluates the coupon inside `Teller.checks_out_articles_from(the_cart)` _before_ calling `the_cart.handle_offers(receipt, self.offers, self.catalog)`, or sums `receipt.items` without subtracting `receipt.discounts`!
- **Correct Fix**: Call `handle_offers` first, compute `net_subtotal = round(receipt.total_price(), 2)` (which already subtracts item discounts), and only add the coupon `Discount` if `net_subtotal >= round(threshold_amount, 2)`.

### Trap 2: Float Representation Drift Blocking Exact `$50.00` Threshold

- **What Naive AI Writes**:
  - `if net_subtotal >= threshold:` without rounding `net_subtotal` to 2 decimals first.
- **Why It Fails**: In IEEE-754 floating-point, `3 * 19.99 - 9.97` evaluates to `49.99999999999999` (`< 50.0`!), causing an exact `$50.00` net cart to fail the `>= 50.0` check!
- **Correct Fix**: Round currency amounts to integer cents (`round(val * 100)`) or `round(val, 2)` before threshold comparison.

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Trace `Teller.checks_out_articles_from`, `ShoppingCart.handle_offers`, and `Receipt.total_price`. Explain how multiple `add_item_quantity` calls for the same product are stored in `items` vs `product_quantities`."_
2. **Step 2 (`Plan`)**:
   - Fix `number_of_xs = quantity_int // x` in `FiveForAmount` / `TwoForAmount`; evaluate loyalty coupon after `handle_offers` using cent-rounded net subtotal.
3. **Step 3 (`Prompt`)** & **Step 4 (`Review`)**:
   - Prompt each change separately and verify float boundary handling (`3 * 19.99 - 9.97 >= 50.00`).

---

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

|   #   | Criterion                        | Strong Hire / Hire (`Score 3–4`)                                                                                                    | No Hire / Blind Vibe-Coder (`Score 1–2`)                                                                                        |
| :---: | :------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------ |
| **1** | **Problem Decomposition**        | Fixes `handle_offers` bundle arithmetic first, then adds post-offer coupon evaluation in `Teller`/`ShoppingCart`.                   | Rewrites all classes at once and breaks existing receipt item ordering.                                                         |
| **2** | **Prompt Context Quality**       | Specifies post-offer net subtotal evaluation and cent-precision comparison (`round(net, 2) >= round(threshold, 2)`).                | Prompts _"Add a coupon feature to SupermarketReceipt"_.                                                                         |
| **3** | **Not Blindly Trusting AI**      | Audits whether AI checks gross vs. net total and checks float precision on `49.99999999999999`.                                     | Accepts AI code that checks gross total before offers are deducted.                                                             |
| **4** | **Code Reading Speed**           | Immediately sees the difference between `self._items` (list of additions) and `self._product_quantities` (aggregated dict).         | Iterates `self._items` instead of `self._product_quantities`, breaking bundles split across multiple `add_item_quantity` calls! |
| **5** | **Bug & Edge-Case Discovery**    | Tests `11` items on `5-for-A`, split `add_item_quantity(2) + add_item_quantity(3)`, and `3 * 19.99 - 9.97 == 50.00`.                | Only tests a single `add_item_quantity(5)` call with round integer prices.                                                      |
| **6** | **Testing Before Claiming Done** | Uncomments all tests and runs `pytest` after every change.                                                                          | Claims done without testing split `add_item_quantity` calls.                                                                    |
| **7** | **Explaining Correctness**       | Explains why `self._product_quantities` must be used for offer calculation and why IEEE-754 float math requires cent normalization. | Cannot explain why `3 * 19.99 - 9.97 < 50.0` in binary floating point.                                                          |

### Interviewer Probing Questions (Final 10 Minutes)

1. **Q**: _"Why does `ShoppingCart` maintain both `_items` (a list) and `_product_quantities` (a dict), and what goes wrong if you evaluate offers over `_items`?"_  
   **Expected Answer**: `_items` preserves the line-by-line scan order for printing the receipt, while `_product_quantities` aggregates total quantity per product across the whole cart. If a customer scans 1 toothbrush at the start and 2 more at the end, evaluating a `3-for-2` offer over `_items` individually misses the bundle!

2. **Q**: _"Why must the loyalty coupon threshold be checked against the post-offer subtotal rather than the gross subtotal?"_
   **Expected Answer**: Otherwise a coupon could be granted on a cart whose discounted total is below the threshold, leaking revenue.
