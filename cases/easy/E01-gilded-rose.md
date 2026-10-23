# E01 — Gilded Rose Inventory Bugfix & Conjured Decay Cap

[⬅️ Back to Easy Catalog](README.md) · [🏠 Master Hub](../../README.md)

| Attribute                    | Details                                                                                                                              |
| :--------------------------- | :----------------------------------------------------------------------------------------------------------------------------------- |
| **Case ID**                  | `E01`                                                                                                                                |
| **Difficulty Level**         | 🟢 **Easy** (`30–45 mins` — Junior / Mid Bar)                                                                                        |
| **Task Archetype**           | Legacy Refactoring + Feature Extension                                                                                               |
| **Source GitHub Repository** | [`emilybache/GildedRose-Refactoring-Kata`](https://github.com/emilybache/GildedRose-Refactoring-Kata)                                |
| **Target Files**             | `gilded_rose.py` & `test_gilded_rose.py` _(or `TypeScript/`, `go/`, `Java/`, `rust/`, `csharpcore/`)_                                |
| **Supported Languages**      | `Python`, `TypeScript`, `Go`, `Java`, `Rust`, `C#`                                                                                   |
| **Primary AI Traps**         | `"Conjured"` prefix check corrupting `"Conjured Aged Brie"` & `"Conjured Sulfuras"` · Post-expiration `quality = 1` dropping to `-3` |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/emilybache/GildedRose-Refactoring-Kata.git gilded-rose-interview
cd gilded-rose-interview/python # (or TypeScript / go / Java / rust / csharpcore)
rm -rf ../.git && git init && git add . && git commit -m "Initial interview baseline"
pytest
```

### Seeded Defects to Inject Before the Session

1. **Bug 1 (Backstage Pass Post-Concert Quality Floor / Cap Off-by-One)**: Seed a bug in `gilded_rose` where `Backstage passes` with `sell_in == 5` (or `sell_in == 10`) uses `< 5` instead of `< 6`, or where post-concert quality drops by `1` instead of dropping to `0`.
2. **Commented Tests**: Add commented-out unit tests in `test_gilded_rose` for `Backstage passes` boundary days (`sell_in = 10, 5, 0`), `"Conjured Mana Cake"`, `"Conjured Aged Brie"`, and `"Conjured Sulfuras, Hand of Ragnaros"`.

---

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
>
> You are working on the inventory quality updater for the **Gilded Rose** inn. You may use the AI Assistant as much or as little as you like.
>
> ### Domain Rules
>
> Every item has two properties:
>
> - `sell_in`: Number of days remaining to sell the item.
> - `quality`: How valuable the item is (`0 <= quality <= 50` for all items except `"Sulfuras"`).
>
> At the end of each day, `update_quality()` lowers both values for every item according to these rules:
>
> 1. **Standard Items**: Degrade in `quality` by `1` before expiration (`sell_in > 0`), and by `2` per day once the sell-by date has passed (`sell_in <= 0`).
> 2. **`"Aged Brie"`**: Actually _increases_ in `quality` the older it gets (`+1` when `sell_in > 0`, `+2` when `sell_in <= 0`), capped at `50`.
> 3. **`"Sulfuras, Hand of Ragnaros"`**: A legendary item; its `sell_in` never changes and its `quality` is always `80` (never alters).
> 4. **`"Backstage passes to a TAFKAL80ETC concert"`**: Increases in `quality` by `+1` when `sell_in > 10`, by `+2` when `6 <= sell_in <= 10`, by `+3` when `1 <= sell_in <= 5`, and drops to **`0`** after the concert (`sell_in <= 0`), always capped at `50`.
> 5. **New Requirement — `"Conjured"` Items (Prefix `"Conjured "`)**:
>    - Normal Conjured items (e.g., `"Conjured Mana Cake"`) degrade in `quality` **twice as fast** as standard items (`-2` when `sell_in > 0`, `-4` when `sell_in <= 0`), floored at `0`.
>    - `"Conjured Aged Brie"` increases in `quality` **twice as fast** as normal `"Aged Brie"` (`+2` when `sell_in > 0`, `+4` when `sell_in <= 0`), capped at `50`.
>    - `"Conjured Sulfuras, Hand of Ragnaros"` remains legendary (`sell_in` unchanged, `quality == 80`).
>    - Note: You must **not** alter the `Item` class or `items` property signature!
>
> ### Your Tasks
>
> 1. **Explore & Run Tests**: Open `gilded_rose` and `test_gilded_rose`. Run the unit test suite.
> 2. **Uncomment & Fix Existing Bugs**: Uncomment the disabled tests in `test_gilded_rose` and fix the existing boundary bug in `Backstage passes`.
> 3. **Refactor & Implement `"Conjured"` Support**: Cleanly support `"Conjured "` items (including `"Conjured Aged Brie"` and `"Conjured Sulfuras"`).
> 4. **Verify Edge Cases**: Test `Conjured` items with `quality = 1` and `sell_in = 0` (must clamp to `0`, never negative!) and `Conjured Aged Brie` with `quality = 49` (must clamp to `50`).

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Checking `if name.startswith("Conjured")` as a Separate Category That Subtracts Quality

- **What Naive AI Writes**:
  ```python
  if item.name.startswith("Conjured"):
      degrade = 4 if item.sell_in <= 0 else 2
      item.quality = max(0, item.quality - degrade)
  ```
- **Why It Fails**: This treats `"Conjured Aged Brie"` and `"Conjured Sulfuras, Hand of Ragnaros"` as normal degrading items—subtracting quality from `"Conjured Aged Brie"` (which should _increase_ by `+2`/`+4`) and reducing `"Conjured Sulfuras"` from `80` to `78`!
- **Correct Fix**: Parse the `"Conjured "` modifier multiplier (`multiplier = 2 if is_conjured else 1`) independently from the base item type (`Sulfuras`, `Aged Brie`, `Backstage passes`, `Standard`), and clamp quality to `[0, 50]` for all non-Sulfuras items!

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Trace `update_quality()` in `gilded_rose.py` and list the exact `sell_in` and `quality` transitions for each item type."_
2. **Step 2 (`Plan`)**:
   - Plan a clean helper `update_single_item(item)` that strips/detects the `"Conjured "` prefix (`multiplier = 2`), dispatches on base item name (`Sulfuras`, `Aged Brie`, `Backstage passes`, `Standard`), and clamps `item.quality = min(50, max(0, item.quality))`.
3. **Step 3 (`Prompt`)** & **Step 4 (`Review`)**:
   - Prompt the refactoring and `"Conjured"` multiplier; verify `Item` class was not modified.

---

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

|   #   | Criterion                        | Strong Hire / Hire (`Score 3–4`)                                                                                   | No Hire / Blind Vibe-Coder (`Score 1–2`)                                                                         |
| :---: | :------------------------------- | :----------------------------------------------------------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------- |
| **1** | **Problem Decomposition**        | Separates `is_conjured` multiplier detection from base item strategy and quality clamping `[0, 50]`.               | Adds more nested `if/else` branches inside the legacy 60-line loop.                                              |
| **2** | **Prompt Context Quality**       | Specifies that `"Conjured "` is a 2x rate modifier on the underlying item type and that `Item` cannot be modified. | Prompts _"Implement Gilded Rose with Conjured items"_, getting generic code that ignores `"Conjured Aged Brie"`. |
| **3** | **Not Blindly Trusting AI**      | Audits how AI handles `"Conjured Sulfuras"` and `"Conjured Aged Brie"`.                                            | Accepts AI code that degrades `"Conjured Aged Brie"` and `"Conjured Sulfuras"`.                                  |
| **4** | **Code Reading Speed**           | Traces the legacy nested `if` conditions in `update_quality` within 5 minutes.                                     | Misreads when `item.sell_in = item.sell_in - 1` happens relative to the `sell_in < 0` check.                     |
| **5** | **Bug & Edge-Case Discovery**    | Tests `sell_in = 0, quality = 1` (`1 - 4 -> clamped to 0`) and `quality = 49` (`49 + 4 -> clamped to 50`).         | Misses negative quality underflow when `quality = 1` degrades by `4`.                                            |
| **6** | **Testing Before Claiming Done** | Uncomments all tests and adds table-driven tests for all 4 base types with and without `"Conjured "`.              | Runs only the default stub test (`foo`).                                                                         |
| **7** | **Explaining Correctness**       | Explains the Orthogonal Modifier + Strategy design and why clamping at `[0, 50]` prevents overflow/underflow.      | Cannot explain what happens on the exact transition day `sell_in == 0`.                                          |

### Interviewer Probing Questions (Final 10 Minutes)

1. **Q**: _"Why is modeling `'Conjured'` as a rate multiplier (`2x`) cleaner than modeling `'Conjured'` as a 5th mutually exclusive item subclass?"_  
   **Expected Answer**: Because `'Conjured'` is an orthogonal modifier that can apply to any item category (`Standard`, `Aged Brie`, `Sulfuras`). Treating it as a `2x` delta multiplier avoids duplicating every item category (`ConjuredBrie`, `ConjuredStandard`, etc.).
