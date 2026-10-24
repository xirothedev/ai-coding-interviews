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

- Failing tests to enable/verify: the repository's existing tests covering this issue. Run the test command to confirm red on Base SHA and green on Merge SHA.

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Bug Report: Legacy Billing AI-Slop Rescue
>
> A legacy billing module contains interlocking defects introduced by an AI-generated patch. It must be refactored to a correct, maintainable implementation.
>
> ### Requirements
>
> - Correct installment splitting so installments sum exactly to the total with proper remainder distribution.
> - Fix tax and rounding calculations.
> - Remove dead code and speculative abstractions; keep behavior covered by tests.
> - Ensure idempotency and transactional consistency.
>
> ### Acceptance Criteria
>
> 1. Trace the billing module and its tests.
> 2. Identify and fix the interlocking defects.
> 3. Refactor for clarity without changing covered behavior.

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Trusting the first plausible fix

- **What Naive AI Writes**: A minimal edit that makes the happy path pass but ignores the edge cases exercised by the real PR (`fix(docker): Skip the build cleanup in a dry run`).
- **Why It Fails**: The PR touches `.github/workflows/release-docker-image.yml`; a shallow change leaves the underlying defect (ordering, caching, type resolution, or retry semantics) in place, so hidden tests still fail.
- **Correct Fix**: Reproduce the failing tests on Base SHA, then implement the same behavior change as the merged PR (study its diff), including edge cases and invariants.

### Trap 2: Over-editing unrelated code

- **What Naive AI Writes**: Refactors surrounding modules "while at it", changing public APIs.
- **Why It Fails**: Breaks callers and the hidden regression tests; the reference solution is minimal and scoped to the PR's changed lines.
- **Correct Fix**: Limit edits to the files/lines indicated by the failing tests; keep diffs small and behavior-focused.

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Trace the current behavior in `.github/workflows/release-docker-image.yml` and identify why the failing tests fail on Base SHA."_
2. **Step 2 (`Plan`)**:
   - Reproduce with the test command; list the minimal files to change.
3. **Step 3 (`Prompt`)**:
   - Prompt 1: Implement the fix matching the merged PR's behavior, scoped to the failing tests.
   - Prompt 2: Add/adjust tests for edge cases (empty input, boundary values, error paths).
4. **Step 4 (`Review`) & Step 5 (`Test`)**:
   - Run the full test command; confirm all previously-failing tests pass and no regressions.

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
