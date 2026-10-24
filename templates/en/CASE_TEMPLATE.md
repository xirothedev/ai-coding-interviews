# [CASE-ID] <Case Title>

> 🌐 Language: **English** · <a href="vi/CASE_TEMPLATE">Tiếng Việt</a>

| Attribute                    | Details                                                                                                         |
| :--------------------------- | :-------------------------------------------------------------------------------------------------------------- |
| **Difficulty Level**         | `Easy` / `Medium` / `Hard`                                                                                      |
| **Task Archetype**           | `Bugfix + Feature Extension` / `Legacy Refactoring & Scale` / `System Component Integration` / `AI-Slop Rescue` |
| **Supported Languages**      | `Python`, `TypeScript`, `Go`, `Java`, `Rust`, `C#`                                                              |
| **Source GitHub Repository** | [`owner/repo`](https://github.com/owner/repo)                                                                   |
| **Target Files**             | `src/...`                                                                                                       |
| **Primary AI Traps**         | `Deceptive Abstraction`, `Toy vs. Prod Scale`, `Conflicting Invariants`, `Concurrency / State`                  |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

Describe the real-world engineering context of the repository and why the team is touching this module today.

### Quick Workspace Setup

```bash
git clone https://github.com/owner/repo.git interview-workspace
cd interview-workspace
# Optional: git checkout <commit-sha-or-tag>
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
```

### Existing / Seeded Bug Manifest

- **Bug 1 (`path/to/file:line`)**: What is broken and why.
- **Bug 2 (`path/to/file:line`)**: How it interacts with Bug 1 or the new feature.

---

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> **Copy and share this section with the candidate (or use it for self-practice before reading sections 3–5).**
>
> **Authoring Guideline (No File Path / Line Number Spoilers!)**: Write this section like a natural Tech Lead prompt, production incident ticket, or GitHub issue report. **Do NOT mention specific filenames, file paths, line numbers, or internal private helper names** here—evaluating how quickly the candidate locates the relevant modules, traces call flows, and builds context for their AI assistant is a core part of the interview!

### Ticket / Problem Statement

Describe the real-world bug report, production incident, or feature request in natural engineering language, as a user or Tech Lead would report it.

### Behavioral Requirements & Invariants

Specify all domain rules, edge-case contracts, backwards-compatibility guarantees, and scale/latency targets clearly so the candidate knows _what_ behavior is required without being told _where_ in the codebase to edit.

### Acceptance Criteria

1. **Explore & Reproduce**: Search the codebase to locate the relevant modules and existing test suite. Uncomment or enable any disabled regression tests and reproduce the reported failures.
2. **Fix Root Causes**: Resolve the underlying defects cleanly without breaking existing callers or public contracts.
3. **Deliver Feature / Scale Target**: Ensure both standard functional fixtures and high-scale/concurrent workloads meet the required invariants and performance budgets.
4. **Verify & Defend**: Add regression tests covering boundary conditions, run the test suite to verify zero regressions, and be ready to walk through your design decisions and trade-offs.

---

## 3. The AI Traps & Expected Solution (Confidential)

### Why Naive Copy-Paste Prompting Fails (The AI Trap)

Explain what happens when a candidate dumps the entire prompt into an LLM (GPT/Claude/Gemini) and blindly accepts the generated diff:

- **Hallucination / Broken Invariant**: ...
- **Hidden Scale / Concurrency Failure**: ...

---

## 4. Reference Divide-and-Conquer Prompt Flow

How a high-performing engineer orchestrates AI on this case using **`Understand → Plan → Prompt → Review → Test`**:

1. **Step 1 (Understand — Map Structure & Trace Flow)**:
   > _"Read `file_a` and `file_b`. Do not write code yet. Trace the execution flow of `func_x()` and list all state mutations and assumptions."_
2. **Step 2 (Plan — Lock Scope, Design & Target Files)**:
   - Candidate identifies exact files and invariants before asking AI to edit.
3. **Step 3 (Prompt — Incremental Micro-Changes)**:
   > _"In `file_a`, update only `helper_y()` to handle [specific condition] while preserving [invariant]. Show a minimal diff."_
4. **Step 4 (Review — Audit Diff, Question Assumptions & Run Tests)**:
   - Candidate spots and corrects AI assumption `X` and runs the test suite.
5. **Step 5 (Test — Edge Cases, Regression Risk & Defense)**:
   - Candidate writes targeted edge-case tests and explains the end-to-end guarantee.

---

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

| Criterion                                 | Green Flags (Score 3–4: Hire / Strong Hire)                                       | Red Flags (Score 1–2: No Hire / Blind Vibe-Coder)                       |
| :---------------------------------------- | :-------------------------------------------------------------------------------- | :---------------------------------------------------------------------- |
| **1. Problem Decomposition**              | Splits bugfix from feature implementation; isolates module boundaries first.      | Pastes all 4 checkpoints into a single mega-prompt.                     |
| **2. Prompt Context Quality**             | Feeds exact file paths, type signatures, and invariants into prompt.              | Gives vague prompts ("fix the tests and implement the solver").         |
| **3. Not Blindly Trusting AI**            | Catches the AI Trap in diff review; questions AI assumptions before applying.     | Applies AI code without reading it; surprised when tests fail.          |
| **4. Code Reading Speed**                 | Quickly maps entry point → core logic → test harness within 10 minutes.           | Cannot explain what existing functions do without asking AI repeatedly. |
| **5. Bug & Edge-Case Discovery**          | Pinpoints root cause and proactively tests empty, duplicate, or scale boundaries. | Fixes symptoms with hacky `if` branches instead of fixing root cause.   |
| **6. Testing Before Claiming Done**       | Runs test suite after every micro-change; adds new regression tests.              | Claims "done" as soon as AI generates code without running tests.       |
| **7. Explaining Why Solution Is Correct** | Clearly articulates complexity, invariants preserved, and trade-offs.             | Says "the AI wrote it this way and the tests pass."                     |
