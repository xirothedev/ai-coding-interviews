# E08 — Delivery Controller Slot Capacity & Time-Zone Cutoff

[⬅️ Back to Easy Catalog](README.md) · [🏠 Master Hub](../../README.md)

| Attribute | Details |
| :--- | :--- |
| **Case ID** | `E08` |
| **Difficulty Level** | 🟢 **Easy** (`30–45 mins` — Junior / Mid Bar) |
| **Task Archetype** | Bugfix + Feature Extension |
| **Source GitHub Repository** | [`emilybache/Delivery-Controller-Refactoring-Kata`](https://github.com/emilybache/Delivery-Controller-Refactoring-Kata) |
| **Target Files** | Delivery controller / slot service & unit tests |
| **Supported Languages** | `Python`, `TypeScript`, `Java`, `C#` |
| **Primary AI Traps** | Non-idempotent booking retry decrementing slot capacity twice for the same `order_id` · Comparing naive timestamp against warehouse local cutoff hour |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Clean-Room Workspace Provisioning
```bash
git clone https://github.com/emilybache/Delivery-Controller-Refactoring-Kata.git delivery-interview
cd delivery-interview
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
```

### Seeded Defects to Inject Before the Session
1. **Bug 1 (Same-Day Cutoff Boundary Off-by-One)**: Orders placed at exactly `12:00:00` warehouse time (or `12:30` when converted from UTC) are mistakenly offered same-day afternoon delivery slots when the cutoff is strictly `< 12:00:00`.
2. **Commented Tests**: Comment out the exact `12:00:00` cutoff boundary test and the idempotent slot reservation tests.

---

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
> You are working on an e-commerce Delivery Slot Controller (`Delivery-Controller-Refactoring-Kata`). You have full access to the AI Assistant and unit test suite.
>
> ### Problem Context
> 1. **Fix Same-Day Cutoff & Timezone Normalization Bug**:
>    - Same-day morning slots require the order to be placed **strictly before `08:00:00`** in the warehouse's local timezone; same-day afternoon slots require the order to be placed **strictly before `12:00:00`** in the warehouse's local timezone.
>    - Orders placed at `08:00:00` or `12:00:00` sharp (or passed as UTC timestamps when the warehouse is `UTC+2`) are currently misclassified!
> 2. **New Feature — Idempotent Slot Capacity Reservation (`reserve_slot(slot_id, order_id)`)**:
>    - Each delivery slot has a `max_capacity: int` (e.g., `10` vans).
>    - `get_available_slots(...)` must exclude any slot that has reached `max_capacity`.
>    - `reserve_slot(slot_id, order_id)`:
>      - **Idempotency Invariant**: If `order_id` has **already** reserved `slot_id`, calling `reserve_slot(slot_id, order_id)` again MUST succeed and return the existing reservation **without decrementing remaining capacity a second time**!
>      - **Slot Switch Invariant**: If `order_id` previously reserved `slot_A` and now calls `reserve_slot(slot_B, order_id)`, it must atomically release `order_id`'s spot in `slot_A` only if `slot_B` has available capacity (if `slot_B` is full, raise `SlotFullError` and keep `order_id`'s reservation in `slot_A` intact!).
>
> ### Your Tasks
> 1. **Explore & Trace**: Inspect the delivery slot filtering and controller code. Run the unit tests.
> 2. **Uncomment & Fix Cutoff Bug**: Uncomment the disabled tests and fix the warehouse timezone and `< 08:00` / `< 12:00` cutoff logic.
> 3. **Implement Idempotent `reserve_slot` & `cancel_reservation`**: Implement capacity tracking with idempotency and atomic slot switching.
> 4. **Verify Edge Cases**: Test retrying `reserve_slot("slot_1", "order_99")` 5 times on a `max_capacity = 1` slot (must succeed all 5 times!), and switching from `"slot_1"` to a full `"slot_2"` (must raise `SlotFullError` while keeping `"order_99"` in `"slot_1"`!).

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Using an Integer Counter `booked_count += 1` Instead of `set[OrderId]`
- **What Naive AI Writes**:
  ```python
  if slot.booked_count >= slot.max_capacity:
      raise SlotFullError()
  slot.booked_count += 1
  ```
- **Why It Fails**:
  1. When `reserve_slot("slot_1", "order_99")` is retried on a `max_capacity = 1` slot, the second call sees `booked_count == 1 == max_capacity` and raises `SlotFullError` instead of returning idempotently!
  2. Even if AI checks `if slot.booked_count >= slot.max_capacity` *before* checking `if order_id in slot.orders`, a retry on a `max_capacity = 1` slot STILL throws `SlotFullError` on retry #2!
- **Correct Fix**:
  1. Check `if order_id in slot.reserved_order_ids: return existing_reservation` **FIRST** (before checking `len(slot.reserved_order_ids) >= slot.max_capacity`!).
  2. When switching from `old_slot` to `new_slot`, check `len(new_slot.reserved_order_ids) >= new_slot.max_capacity` **before** removing `order_id` from `old_slot.reserved_order_ids`!

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > *"Do not write code. Trace how delivery slots and cutoff times are currently evaluated in the controller."*
2. **Step 2 (`Plan`)**:
   - Normalize `order_timestamp` to warehouse timezone first; store reservations per slot as `reserved_orders: set[str]`; check idempotency (`order_id in target_slot.reserved_orders`) *before* capacity check; check `target_slot` capacity *before* releasing `previous_slot`.
3. **Step 3 (`Prompt`)** & **Step 4 (`Review`)**:
   - Audit the order of `if order_id in target_slot` vs `if is_full(target_slot)`.

---

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

| # | Criterion | Strong Hire / Hire (`Score 3–4`) | No Hire / Blind Vibe-Coder (`Score 1–2`) |
| :-: | :--- | :--- | :--- |
| **1** | **Problem Decomposition** | Separates timezone cutoff calculation from the stateful slot reservation tracker. | Mixes timestamp parsing and reservation dictionaries in one giant method. |
| **2** | **Prompt Context Quality** | Specifies checking `order_id in target_slot` *before* checking `is_full` so `max_capacity=1` retries succeed, and validating `target_slot` capacity before releasing `old_slot`. | Prompts *"Add slot capacity and reservation"*. |
| **3** | **Not Blindly Trusting AI** | Spots the ordering bug (`if is_full` before `if already_reserved`) and the non-atomic slot-switch bug (`old_slot.remove` before `new_slot` check). | Accepts AI code that checks `if is_full` first, failing idempotent retry when the last spot was taken by that same `order_id`! |
| **4** | **Code Reading Speed** | Quickly identifies the cutoff comparisons (`<=` vs `<`) in the existing code. | Misses the exact `12:00:00` boundary check. |
| **5** | **Bug & Edge-Case Discovery** | Tests idempotent retry when `slot` has `max_capacity=1` (100% full after first call!), and failed slot switch rollback. | Only tests idempotent retry when `max_capacity=10` (`9` spots still free), which hides the `if is_full` ordering bug! |
| **6** | **Testing Before Claiming Done** | Runs all unit tests and adds the `max_capacity=1` retry test and failed slot-switch test. | Claims done without testing `max_capacity=1` retry. |
| **7** | **Explaining Correctness** | Explains why idempotency check must precede capacity check and why slot switching requires check-then-mutate atomicity. | Cannot explain why `max_capacity=1` failed on retry #2. |

### Interviewer Probing Questions (Final 10 Minutes)
1. **Q**: *"Suppose `slot_1` has `max_capacity = 1`. `order_A` reserves `slot_1` (now `1/1` full), and then `order_A` retries `reserve_slot('slot_1', 'order_A')`. What happens if your code checks `if len(slot.orders) >= slot.max_capacity:` on line 1 and `if order_id in slot.orders:` on line 3?"*  
   **Expected Answer**: Line 1 sees `1 >= 1` and raises `SlotFullError` before reaching line 3! The idempotency check (`if order_id in slot.orders: return`) must always run *before* the capacity check.
