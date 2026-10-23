# E02 — Supermarket Receipt Discount Stacking & Bundle Rounding

[⬅️ Back to Easy Catalog](README.md) · [🏠 Master Hub](../../README.md)

| Attribute | Details |
| :--- | :--- |
| **Case ID** | `E02` |
| **Difficulty Level** | 🟢 **Easy** (`30–45 mins` — Junior / Mid Bar) |
| **Task Archetype** | Bugfix + Feature Extension |
| **Source GitHub Repository** | [`emilybache/SupermarketReceipt-Refactoring-Kata`](https://github.com/emilybache/SupermarketReceipt-Refactoring-Kata) |
| **Target Files** | `shopping_cart.py`, `teller.py`, `receipt.py`, `model_objects.py`, `test_supermarket.py` |
| **Supported Languages** | `Python`, `TypeScript`, `Go`, `Java`, `Rust`, `C#` |
| **Primary AI Traps** | Partial bundle remainder bug (`7` items on `5-for-X`) · Evaluating minimum-spend coupon against gross pre-bundle total instead of net total · Float precision drift |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Clean-Room Workspace Provisioning
```bash
git clone https://github.com/emilybache/SupermarketReceipt-Refactoring-Kata.git supermarket-interview
cd supermarket-interview/python # (or TypeScript / go / java / rust / csharp)
rm -rf ../.git && git init && git add . && git commit -m "Initial interview baseline"
pytest
```

### Seeded Defects to Inject Before the Session
1. **Bug 1 (Multi-Bundle Remainder Calculation in `ShoppingCart.handle_offers`)**: In `TwoForAmount` or `FiveForAmount`, seed an integer division bug (`int(quantity) // 5` without multiplying the bundle price by `number_of_bundles`, so buying `10` toothpastes on a `5-for-$7.49` offer charges `$7.49` for the first 5 and full price for the next 5!).
2. **Commented Tests**: Comment out `test_ten_items_on_five_for_amount_offer` and `test_coupon_threshold_after_bundle_discounts` in `test_supermarket`.

---

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
> You are working on a supermarket checkout & receipt calculation engine. You have full access to the AI Assistant and unit test suite.
>
> ### Problem Context
> 1. **Bug in Multi-Bundle Offers (`ShoppingCart.handle_offers`)**:
>    - Customers buying multiple full bundles (e.g., `10` or `12` items on a `5-for-$7.49` or `2-for-$1.50` offer, potentially added across multiple `add_item_quantity` calls) are being overcharged!
>    - For quantity `Q` on an `N-for-$A` offer (with unit price `P`): `bundles = int(Q) // N` and `remainder = Q - (bundles * N)`. Total cost for that product must be `bundles * A + remainder * P`.
> 2. **New Feature — Minimum-Spend Cart Coupon (`apply_loyalty_coupon`)**:
>    - Support a cart-level coupon `(threshold_amount, discount_amount)`:
>      - The `threshold_amount` MUST be evaluated against the **net cart subtotal AFTER all product-level offers (`ThreeForTwo`, `FiveForAmount`, `TenPercentDiscount`, etc.) have been deducted**—NOT the gross pre-discount subtotal!
>      - Example: Gross items = `$52.00`, bundle discounts = `-$5.00` → Net subtotal = `$47.00`. A `"$10 off $50+"` coupon does **NOT** apply because `$47.00 < $50.00`!
>      - Final receipt total must be rounded cleanly to 2 decimal places (`round(total, 2)`) and never drop below `0.00`.
>
> ### Your Tasks
> 1. **Explore & Trace**: Read `teller.py`, `shopping_cart.py`, `receipt.py`, and `model_objects.py`.
> 2. **Run & Uncomment Tests**: Run `pytest` and uncomment the multi-bundle and loyalty coupon tests in `test_supermarket.py`.
> 3. **Fix Multi-Bundle Offers & Implement Net-Threshold Loyalty Coupon**: Fix the bundle math and add loyalty coupon evaluation.
> 4. **Verify Edge Cases**: Test adding the same product in 3 separate `add_item_quantity` calls (`2 + 2 + 3 = 7` items on `5-for-A`), weighted items (`1.5 kg`), and floating-point boundary (`net_subtotal == 49.99999999999999` vs `50.00`).

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Checking Coupon Threshold Against `receipt.total_price()` Before Offers Are Applied
- **What Naive AI Writes**:
  - Evaluates the coupon inside `Teller.checks_out_articles_from(the_cart)` *before* calling `the_cart.handle_offers(receipt, self.offers, self.catalog)`, or sums `receipt.items` without subtracting `receipt.discounts`!
- **Correct Fix**: Call `handle_offers` first, compute `net_subtotal = round(receipt.total_price(), 2)` (which already subtracts item discounts), and only add the coupon `Discount` if `net_subtotal >= round(threshold_amount, 2)`.

### Trap 2: Float Representation Drift Blocking Exact `$50.00` Threshold
- **What Naive AI Writes**:
  - `if net_subtotal >= threshold:` without rounding `net_subtotal` to 2 decimals first.
- **Why It Fails**: In IEEE-754 floating-point, `3 * 19.99 - 9.97` evaluates to `49.99999999999999` (`< 50.0`!), causing an exact `$50.00` net cart to fail the `>= 50.0` check!
- **Correct Fix**: Round currency amounts to integer cents (`round(val * 100)`) or `round(val, 2)` before threshold comparison.

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > *"Do not write code. Trace `Teller.checks_out_articles_from`, `ShoppingCart.handle_offers`, and `Receipt.total_price`. Explain how multiple `add_item_quantity` calls for the same product are stored in `items` vs `product_quantities`."*
2. **Step 2 (`Plan`)**:
   - Fix `number_of_xs = quantity_int // x` in `FiveForAmount` / `TwoForAmount`; evaluate loyalty coupon after `handle_offers` using cent-rounded net subtotal.
3. **Step 3 (`Prompt`)** & **Step 4 (`Review`)**:
   - Prompt each change separately and verify float boundary handling (`3 * 19.99 - 9.97 >= 50.00`).

---

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

| # | Criterion | Strong Hire / Hire (`Score 3–4`) | No Hire / Blind Vibe-Coder (`Score 1–2`) |
| :-: | :--- | :--- | :--- |
| **1** | **Problem Decomposition** | Fixes `handle_offers` bundle arithmetic first, then adds post-offer coupon evaluation in `Teller`/`ShoppingCart`. | Rewrites all classes at once and breaks existing receipt item ordering. |
| **2** | **Prompt Context Quality** | Specifies post-offer net subtotal evaluation and cent-precision comparison (`round(net, 2) >= round(threshold, 2)`). | Prompts *"Add a coupon feature to SupermarketReceipt"*. |
| **3** | **Not Blindly Trusting AI** | Audits whether AI checks gross vs. net total and checks float precision on `49.99999999999999`. | Accepts AI code that checks gross total before offers are deducted. |
| **4** | **Code Reading Speed** | Immediately sees the difference between `self._items` (list of additions) and `self._product_quantities` (aggregated dict). | Iterates `self._items` instead of `self._product_quantities`, breaking bundles split across multiple `add_item_quantity` calls! |
| **5** | **Bug & Edge-Case Discovery** | Tests `11` items on `5-for-A`, split `add_item_quantity(2) + add_item_quantity(3)`, and `3 * 19.99 - 9.97 == 50.00`. | Only tests a single `add_item_quantity(5)` call with round integer prices. |
| **6** | **Testing Before Claiming Done** | Uncomments all tests and runs `pytest` after every change. | Claims done without testing split `add_item_quantity` calls. |
| **7** | **Explaining Correctness** | Explains why `self._product_quantities` must be used for offer calculation and why IEEE-754 float math requires cent normalization. | Cannot explain why `3 * 19.99 - 9.97 < 50.0` in binary floating point. |

### Interviewer Probing Questions (Final 10 Minutes)
1. **Q**: *"Why does `ShoppingCart` maintain both `_items` (a list) and `_product_quantities` (a dict), and what goes wrong if you evaluate offers over `_items`?"*  
   **Expected Answer**: `_items` preserves the line-by-line scan order for printing the receipt, while `_product_quantities` aggregates total quantity per product across the whole cart. If a customer scans 1 toothbrush at the start and 2 more at the end, evaluating a `3-for-2` offer over `_items` individually misses the bundle!
