# E03 — Theatrical Players Statement Formatter & HTML Loyalty Credits

[⬅️ Back to Easy Catalog](README.md) · [🏠 Master Hub](../../README.md)

| Attribute | Details |
| :--- | :--- |
| **Case ID** | `E03` |
| **Difficulty Level** | 🟢 **Easy** (`30–45 mins` — Junior / Mid Bar) |
| **Task Archetype** | System Component Integration & Refactoring |
| **Source GitHub Repository** | [`emilybache/Theatrical-Players-Refactoring-Kata`](https://github.com/emilybache/Theatrical-Players-Refactoring-Kata) |
| **Target Files** | `statement.py` & `test_statement.py` *(or `TypeScript/`, `go/`, `Java/`, `rust/`, `csharp/`)* |
| **Supported Languages** | `Python`, `TypeScript`, `Go`, `Java`, `Rust`, `C#` |
| **Primary AI Traps** | Duplicating pricing math between `statement()` and `html_statement()` · Single-pass loop failing to detect cross-play repertoire bonus when `"tragedy"` appears *after* `"history"` |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Clean-Room Workspace Provisioning
```bash
git clone https://github.com/emilybache/Theatrical-Players-Refactoring-Kata.git theatrical-interview
cd theatrical-interview/python # (or TypeScript / go / java / rust / csharp)
rm -rf ../.git && git init && git add . && git commit -m "Initial interview baseline"
pytest
```

### Seeded Defects to Inject Before the Session
1. **Bug 1 (Comedy Audience Boundary Off-by-One)**: In `statement.py`, change `if perf['audience'] > 20:` to `if perf['audience'] >= 20:` (or change `math.floor(perf['audience'] / 5)` to integer division that rounds wrong), causing the boundary test for `audience == 20` to fail.
2. **Commented Tests**: Comment out `test_comedy_exact_boundary_20`, `test_html_statement`, and `test_history_play_repertoire_bonus` in `test_statement.py`.

---

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
> You are working on the invoice statement generator for a theatrical company (`Theatrical-Players-Refactoring-Kata`). You have full access to the AI Assistant and unit test suite.
>
> ### Problem Context
> 1. **Fix Existing Comedy Boundary Bug**:
>    - For `"comedy"` plays, base cost is `$300.00` (`30000` cents) plus `$3.00` (`300` cents) per attendee. If `audience > 20` (strictly greater than 20), add a `$100.00` (`10000` cents) surcharge plus `$5.00` (`500` cents) for each attendee over `20`.
>    - Currently, `audience == 20` is being overcharged!
> 2. **New Play Type — `"history"` & Repertoire Bonus Rule**:
>    - Base cost: `$350.00` (`35000` cents). If `audience > 25`, add `$15.00` (`1500` cents) for each attendee over `25`.
>    - Volume credits for `"history"`: Base credits = `max(audience - 25, 0) + math.floor(audience / 10)`.
>    - **Cross-Play Repertoire Bonus**: If the customer's invoice contains **at least one `"tragedy"` play AND at least one `"history"` play** (in **any** order in `invoice["performances"]`!), every `"history"` performance on that invoice receives **double (`2x`)** its volume credits!
> 3. **HTML Statement Renderer (`html_statement(invoice, plays)`)**:
>    - Implement `html_statement(invoice, plays)` returning an HTML table/list matching the exact numbers of `statement(invoice, plays)` without duplicating pricing or credit calculation formulas across the two functions!
>
> ### Your Tasks
> 1. **Explore & Run Tests**: Read `statement.py` and `test_statement.py`, and run `pytest`.
> 2. **Uncomment & Fix Boundary Bug**: Uncomment the tests in `test_statement.py` and fix the `comedy` `audience == 20` bug.
> 3. **Refactor (Split Phase) & Add `"history"` + `html_statement`**: Extract a shared intermediate calculation model so `statement()` and `html_statement()` share 100% of pricing/credit logic, and implement `"history"`.
> 4. **Verify Edge Cases**: Test an invoice where `"history"` is the **first** performance in the list and `"tragedy"` is the **last** performance (verifying the `2x` history credit bonus still triggers!).

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Evaluating the `"tragedy" + "history"` Bonus in a Single Left-to-Right Loop
- **What Naive AI Writes**:
  ```python
  seen_tragedy = False
  for perf in invoice["performances"]:
      play = plays[perf["playID"]]
      if play["type"] == "tragedy":
          seen_tragedy = True
      elif play["type"] == "history":
          credits = base_history_credits(perf["audience"])
          if seen_tragedy: # <-- BUG! False if "history" comes BEFORE "tragedy" in the list!
              credits *= 2
  ```
- **Why It Fails**: When `invoice["performances"]` has `[history_perf, tragedy_perf]`, `seen_tragedy` is still `False` when `history_perf` is processed at index 0!
- **Correct Fix**: Pre-compute invoice-level flags before iterating performances:
  ```python
  play_types = {plays[p["playID"]]["type"] for p in invoice["performances"]}
  has_repertoire_bonus = "tragedy" in play_types and "history" in play_types
  ```

### Trap 2: Copy-Pasting Pricing Logic into `html_statement()`
- **What Naive AI Writes**: Duplicates the entire `for perf in invoice['performances']` calculation loop inside `html_statement()`.
- **Correct Fix**: Follow Martin Fowler's **Split Phase** pattern: `compute_statement_data(invoice, plays) -> StatementData` (pure calculation), consumed by both `render_plain_text(data)` and `render_html(data)`.

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > *"Do not write code. Inspect `statement.py` and `test_statement.py` and identify why `audience == 20` fails for comedy."*
2. **Step 2 (`Plan`)**:
   - Fix `audience > 20`; extract `compute_statement_data(invoice, plays)` returning `{ customer, lines, total_amount, volume_credits }`; pre-compute `play_types` set for the `"history" + "tragedy"` bonus; add `render_plain_text` and `render_html`.
3. **Step 3 (`Prompt`)** & **Step 4 (`Review`)**:
   - Prompt the `compute_statement_data` extraction first, verify existing tests pass, then add `"history"` and `html_statement`.

---

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

| # | Criterion | Strong Hire / Hire (`Score 3–4`) | No Hire / Blind Vibe-Coder (`Score 1–2`) |
| :-: | :--- | :--- | :--- |
| **1** | **Problem Decomposition** | Uses Fowler's *Split Phase* (Calculation vs Rendering) before adding `html_statement` and `"history"`. | Copy-pastes `statement()` into `html_statement()` and edits both separately. |
| **2** | **Prompt Context Quality** | Specifies `compute_statement_data` extraction and pre-scanning `play_types` for order-independent repertoire bonus. | Prompts *"Add history play and html_statement"* in one vague request. |
| **3** | **Not Blindly Trusting AI** | Checks whether AI's repertoire bonus depends on performance array order (`[history, tragedy]` vs `[tragedy, history]`). | Accepts a single-pass `seen_tragedy` boolean that fails when `"history"` is first. |
| **4** | **Code Reading Speed** | Spots the `>= 20` vs `> 20` comedy bug within 3 minutes. | Needs AI to find the off-by-one bug in a 40-line function. |
| **5** | **Bug & Edge-Case Discovery** | Tests `[history, tragedy]` ordering, `audience = 25` boundary for history, and unknown play type error handling. | Only tests `[tragedy, history]` ordering. |
| **6** | **Testing Before Claiming Done** | Runs `pytest` after refactoring and adds order-permutation assertions for `[history, tragedy]`. | Claims done without testing reverse performance order. |
| **7** | **Explaining Correctness** | Explains Split Phase architecture (zero duplicated domain math) and why invoice-level invariants require a two-pass or set pre-check. | Cannot explain what happens if pricing rules change in the future when logic is duplicated in two functions. |

### Interviewer Probing Questions (Final 10 Minutes)
1. **Q**: *"If the business changes comedy surcharge from `> 20` to `> 25` tomorrow, how many places in your code need to change so both text and HTML statements stay in sync?"*  
   **Expected Answer**: Exactly 1 place (`compute_statement_data`), because calculation is completely decoupled from text/HTML formatting.
