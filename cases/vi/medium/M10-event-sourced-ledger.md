# M10 — Event-Sourced Bank Ledger & Out-of-Order Webhook Reconciliation

[⬅️ Back to Medium Catalog](README.md) · [🏠 Master Hub](../../../README.md)

| Attribute                    | Details                                                                                                                                                                                                                                                                                                                              |
| :--------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Case ID**                  | `M10`                                                                                                                                                                                                                                                                                                                                |
| **Difficulty Level**         | 🟡 **Medium** (`45–60 mins` — Standard SWE Bar)                                                                                                                                                                                                                                                                                      |
| **Task Archetype**           | Code Review & AI-Slop Rescue + Domain State Machine                                                                                                                                                                                                                                                                                  |
| **Source GitHub Repository** | [`MARKASCHARAN/ChronoLedger`](https://github.com/MARKASCHARAN/ChronoLedger) · [`Zubimendi/ReplayLedger`](https://github.com/Zubimendi/ReplayLedger) · [`HARRIFIED/Event-sourced-core-banking`](https://github.com/HARRIFIED/Event-sourced-core-banking)                                                                              |
| **Target Files**             | `backend/src/domain/payment/payment-fsm.ts`, `backend/src/domain/reconciliation/reconciliation-engine.ts`, `backend/tests/unit/payment-fsm.test.ts` _(or `internal/ledger/derive.go`, `internal/ledger/append.go`, `test/integration/idempotency_test.go` in `ReplayLedger`, or `src/modules/accounts/domain/account.aggregate.ts`)_ |
| **Supported Languages**      | `TypeScript`, `Go`, `Python`, `Java`                                                                                                                                                                                                                                                                                                 |
| **Primary AI Traps**         | Out-of-order `CAPTURE` arriving before `HOLD` · Partial capture (`$80` of `$100` hold) failing to release the `$20` remainder · Duplicate `event_id` replay                                                                                                                                                                          |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Source Repository & Pull Request (Confidential)

| Field                              | Value                                                     |
| :--------------------------------- | :-------------------------------------------------------- |
| **Repository**                     | `https://github.com/HARRIFIED/Event-sourced-core-banking` |
| **Base SHA (pre-merge)**           | `ceaa8bf4b086467d8eb6f91e22ebbe765f9be280`                |
| **Merge SHA (reference solution)** | `fdc15b21361947176577c5fd353f03352a9df5fd`                |
| **Test Command**                   | `npm test`                                                |

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/HARRIFIED/Event-sourced-core-banking.git interview-workspace
cd interview-workspace
git checkout ceaa8bf4b086467d8eb6f91e22ebbe765f9be280
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
npm test
```

### Reproducibility Verification

- **Base SHA (`ceaa8bf4b086`)**: the test suite must contain at least one failing test related to the issue.
- **Merge SHA (`fdc15b213619`)**: the same tests must pass after checkout.

### Files Changed (Reference Solution)

- src/modules/accounts/domain/account.aggregate.ts

### Failing Tests to Enable

- Failing tests to enable/verify: the repository's existing tests covering this issue. Run the test command to confirm red on Base SHA and green on Merge SHA.

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

### Trap 1: Trusting the first plausible fix

- **What Naive AI Writes**: A minimal edit that makes the happy path pass but ignores the edge cases exercised by the real PR (`Command idempotency`).
- **Why It Fails**: The PR touches `src/modules/accounts/domain/account.aggregate.ts`; a shallow change leaves the underlying defect (ordering, caching, type resolution, or retry semantics) in place, so hidden tests still fail.
- **Correct Fix**: Reproduce the failing tests on Base SHA, then implement the same behavior change as the merged PR (study its diff), including edge cases and invariants.

### Trap 2: Over-editing unrelated code

- **What Naive AI Writes**: Refactors surrounding modules "while at it", changing public APIs.
- **Why It Fails**: Breaks callers and the hidden regression tests; the reference solution is minimal and scoped to the PR's changed lines.
- **Correct Fix**: Limit edits to the files/lines indicated by the failing tests; keep diffs small and behavior-focused.

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Trace the current behavior in `src/modules/accounts/domain/account.aggregate.ts` and identify why the failing tests fail on Base SHA."_
2. **Step 2 (`Plan`)**:
   - Reproduce with the test command; list the minimal files to change.
3. **Step 3 (`Prompt`)**:
   - Prompt 1: Implement the fix matching the merged PR's behavior, scoped to the failing tests.
   - Prompt 2: Add/adjust tests for edge cases (empty input, boundary values, error paths).
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Run the full test command; confirm all previously-failing tests pass and no regressions.

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

2. **Q**: _"Why must partial capture release the remaining held amount?"_
   **Expected Answer**: Otherwise the held balance leaks and subsequent captures see a stale reservation.
