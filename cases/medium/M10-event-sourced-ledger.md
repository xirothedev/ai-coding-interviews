# M10 — Event-Sourced Bank Ledger & Out-of-Order Webhook Reconciliation

[⬅️ Back to Medium Catalog](README.md) · [🏠 Master Hub](../../README.md)

| Attribute                    | Details                                                                                                                                                                                                              |
| :--------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Case ID**                  | `M10`                                                                                                                                                                                                                |
| **Difficulty Level**         | 🟡 **Medium** (`45–60 mins` — Standard SWE Bar)                                                                                                                                                                      |
| **Task Archetype**           | Code Review & AI-Slop Rescue + Domain State Machine                                                                                                                                                                  |
| **Source GitHub Repository** | [`oskardudycz/EventSourcing.NetCore`](https://github.com/oskardudycz/EventSourcing.NetCore) · [`cer/event-sourcing-examples`](https://github.com/cer/event-sourcing-examples) _(Backend Ledger / Payment Challenge)_ |
| **Target Files**             | `ledger`, `webhook_processor`, and `test_ledger`                                                                                                                                                                     |
| **Supported Languages**      | `TypeScript`, `Python`, `Java`, `Go`                                                                                                                                                                                 |
| **Primary AI Traps**         | Out-of-order `CAPTURE` arriving before `HOLD` · Partial capture (`$80` of `$100` hold) failing to release the `$20` remainder · Duplicate `event_id` replay                                                          |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Scenario Context

This case simulates Stripe/Fintech-style interviews where a candidate is given a payment ledger & webhook ingestion service previously drafted with AI assistance.
The starter code contains **3 realistic domain bugs**:

1. **Bug 1 (Duplicate Webhook Replay)**: Payment gateways deliver webhooks with at-least-once semantics (`event_id`). Re-delivering an `AUTH_HOLD` or `DEPOSIT` event applies the balance change twice!
2. **Bug 2 (Partial Capture Remainder Leak)**: When a customer has an active `AUTH_HOLD` of `$100.00` (e.g., hotel or gas station pre-auth) and the final `CAPTURE` event is for `$75.00` (`final=true`), the existing code deducts `$75.00` from `settled_balance` but only reduces `held_balance` by `$75.00` instead of releasing the entire `$100.00` hold—leaving `$25.00` permanently frozen in `held_balance`!
3. **Bug 3 (Out-of-Order Webhook Delivery)**: Due to distributed queue jitter, a `CAPTURE(auth_id="a1", amount=5000)` or `VOID(auth_id="a1")` webhook can arrive `50ms` **before** its corresponding `AUTH_HOLD(auth_id="a1", amount=5000)` webhook! Currently, the processor throws `UnknownAuthHoldError` or silently drops the `CAPTURE`.

---

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
>
> You are working on an Event-Sourced Payment Ledger that processes asynchronous card & bank webhooks. You have full access to the AI Assistant and unit test suite.
>
> ### Domain Rules & Ledger Invariants
>
> Every account tracks two balances in **integer cents**:
>
> - `settled_balance`: Confirmed funds in the account (modified by `DEPOSIT`, `WITHDRAWAL`, and `CAPTURE`).
> - `held_balance`: Funds currently locked in active `AUTH_HOLD`s.
> - `available_balance`: Always defined as **`settled_balance - held_balance`**.
>
> #### Webhook Event Types
>
> 1. `DEPOSIT(event_id, account_id, amount_cents)` → Increases `settled_balance` by `amount_cents`.
> 2. `WITHDRAWAL(event_id, account_id, amount_cents)` → Requires `available_balance >= amount_cents`; decreases `settled_balance` by `amount_cents` (otherwise raises `InsufficientFundsError`).
> 3. `AUTH_HOLD(event_id, account_id, auth_id, amount_cents)` → Requires `available_balance >= amount_cents` (unless already captured out-of-order); increases `held_balance` by `amount_cents`.
> 4. `CAPTURE(event_id, account_id, auth_id, amount_cents)` → Settles a hold:
>    - `amount_cents` may be **less than or equal to** the original `AUTH_HOLD` amount (_Partial Capture_, e.g., `$100` hold at a gas pump, `$65` final capture).
>    - Decreases `settled_balance` by `capture_amount_cents` AND releases the **entire** remaining hold for `auth_id` from `held_balance`!
> 5. `VOID(event_id, account_id, auth_id)` → Cancels an unsettled `AUTH_HOLD`, releasing its held amount back to `available_balance` without changing `settled_balance`.
>
> #### Critical Reliability Requirements
>
> - **Idempotency**: Duplicate deliveries of the same `event_id` must be a safe no-op returning the existing result.
> - **Out-of-Order Tolerance**: If `CAPTURE(auth_id="x")` or `VOID(auth_id="x")` arrives **before** `AUTH_HOLD(auth_id="x")`, record the pending resolution or settle immediately so that when `AUTH_HOLD(auth_id="x")` arrives later, the final `(settled_balance, held_balance, available_balance)` is **100% identical** to in-order delivery!
>
> ### Your Tasks
>
> 1. **Explore & Audit**: Read the ledger and webhook processor code and run the existing tests.
> 2. **Uncomment Failing Tests**: Uncomment the idempotency, partial-capture, and out-of-order webhook permutation tests.
> 3. **Fix All 3 Ledger Defects**: Implement idempotent event tracking, proper partial-capture hold release, and out-of-order `HOLD` / `CAPTURE` / `VOID` reconciliation.
> 4. **Verify Permutation Invariant**: Write a test proving that for any sequence of events on `auth_id`, all delivery permutations of `[AUTH_HOLD, CAPTURE]` and `[AUTH_HOLD, VOID]` converge to the exact same account balances.

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Subtracting `capture.amount` Instead of `hold.amount` from `held_balance`

- **What Naive AI Writes**:
  ```python
  account.settled_balance -= event.amount_cents
  account.held_balance -= event.amount_cents # <-- BUG when capture ($65) < hold ($100)!
  ```
- **Why It Fails**: If `hold = 10000` (`$100`) and `capture = 6500` (`$65`), subtracting `6500` from `held_balance` leaves `3500` (`$35`) stuck in `held_balance` forever!
- **Correct Fix**: Transition the authorization state machine (`PENDING -> CAPTURED`), deduct `capture.amount_cents` from `settled_balance`, and deduct `hold.remaining_held_cents` (`10000`) from `held_balance`!

### Trap 2: Double-Deducting or Negative `held_balance` When `CAPTURE` Arrives Before `AUTH_HOLD`

- **What Naive AI Writes**:
  - When `CAPTURE(auth_id="a1", amount=6500)` arrives first (no `hold` found yet), the AI subtracts `6500` from `settled_balance` AND subtracts `6500` from `held_balance` (making `held_balance = -6500`!). Then when `AUTH_HOLD(auth_id="a1", amount=10000)` arrives later, it adds `10000` to `held_balance`, leaving `held_balance = +3500`!
- **Correct Fix (Explicit per-`auth_id` State Machine)**:
  Track each `auth_id` with state:
  - `UNSEEN` → if `CAPTURE(c)` arrives first: deduct `c` from `settled_balance`, set auth state to `CAPTURED_EARLY(captured_amount=c)` (`held_balance` unchanged = `0`). When `AUTH_HOLD(h)` arrives later for an already-`CAPTURED_EARLY` `auth_id`: verify `h >= c` and treat as already settled (do NOT add `h` to `held_balance`!).
  - Similarly, if `VOID` arrives first: set auth state to `VOIDED_EARLY`. When `AUTH_HOLD(h)` arrives later: no-op!

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Trace how `AUTH_HOLD`, `CAPTURE`, and `VOID` currently mutate `settled_balance` and `held_balance`. Show what happens on a partial capture (`hold=100, capture=65`) and out-of-order `[CAPTURE, AUTH_HOLD]`."_
2. **Step 2 (`Plan`)**:
   - Design the per-`auth_id` state machine (`OPEN(hold_cents)`, `CAPTURED(capture_cents)`, `VOIDED`) so any arrival order of `HOLD`, `CAPTURE`, and `VOID` transitions deterministically.
3. **Step 3 (`Prompt`)** & **Step 4 (`Review`)**:
   - Prompt the `AuthorizationRecord` state machine first, then wire `event_id` idempotency and balance updates.

---

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

|   #   | Criterion                        | Strong Hire / Hire (`Score 3–4`)                                                                                                                   | No Hire / Blind Vibe-Coder (`Score 1–2`)                                                                                  |
| :---: | :------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------ |
| **1** | **Problem Decomposition**        | Models the `auth_id` lifecycle as a explicit finite state machine (`UNSEEN`, `HELD`, `CAPTURED`, `VOIDED`) before touching account balances.       | Patches ad-hoc `if/else` flags onto `Account` without a state machine.                                                    |
| **2** | **Prompt Context Quality**       | Explicitly specifies partial capture (`capture < hold` releases full `hold_amount`) and early-capture/early-void state transitions.                | Prompts _"Handle out of order webhooks in `webhook_processor`"_.                                                          |
| **3** | **Not Blindly Trusting AI**      | Catches the negative `held_balance` bug when `CAPTURE` arrives before `HOLD` (`hold=100, capture=65`).                                             | Accepts AI code that does `held_balance -= capture_amount` on early capture, leaving `35` stuck when `HOLD(100)` arrives! |
| **4** | **Code Reading Speed**           | Spots all 3 seeded bugs in the starter code within 10 minutes.                                                                                     | Fails to notice `held_balance -= event.amount` is wrong for partial captures.                                             |
| **5** | **Bug & Edge-Case Discovery**    | Tests `[CAPTURE(65), AUTH_HOLD(100)]` (out-of-order partial capture!), duplicate `CAPTURE` replay, and `CAPTURE` after `VOID`.                     | Only tests `[CAPTURE(100), AUTH_HOLD(100)]` where `capture == hold` hides the arithmetic bug!                             |
| **6** | **Testing Before Claiming Done** | Writes a permutation test asserting `in_order_state == out_of_order_state` on partial captures (`hold=100, capture=65`).                           | Only tests equal amounts (`hold=100, capture=100`).                                                                       |
| **7** | **Explaining Correctness**       | Draws/explains the commutative state machine diagram for `(HOLD, CAPTURE, VOID)` and why `available == settled - held` is preserved at every step. | Cannot explain what happens if `CAPTURE(65)` arrives before `AUTH_HOLD(100)`.                                             |

### Interviewer Probing Questions (Final 10 Minutes)

1. **Q**: _"Walk through your code when `CAPTURE(auth_id='a1', amount=65)` arrives FIRST, and `AUTH_HOLD(auth_id='a1', amount=100)` arrives SECOND, starting from `settled = 500, held = 0`."_  
   **Expected Answer**: On `CAPTURE(65)`: `auth['a1']` transitions from `UNSEEN` to `CAPTURED(65)`, `settled` becomes `435`, `held` stays `0`, `available` is `435`. On `AUTH_HOLD(100)`: since `auth['a1']` is already `CAPTURED(65)` (and `65 <= 100`), the hold is already resolved—`settled` stays `435` and `held` stays `0`, matching the in-order result!
