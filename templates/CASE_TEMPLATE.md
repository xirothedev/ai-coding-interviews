# [CASE-ID] <Case Title>

| Attribute | Details |
| :--- | :--- |
| **Difficulty Level** | `Easy` / `Medium` / `Hard` |
| **Task Archetype** | `Bugfix + Feature Extension` / `Legacy Refactoring & Scale` / `System Component Integration` / `AI-Slop Rescue` |
| **Primary Languages** | `Python`, `TypeScript`, `Go`, `Java`, `Rust`, `C#` |
| **Source GitHub Repository** | [`owner/repo`](https://github.com/owner/repo) |
| **Target Module / Path** | `src/...` |
| **Recommended Time** | `45–60 minutes` |
| **AI Trap Categories** | `Deceptive Abstraction`, `Toy vs. Prod Scale`, `Conflicting Invariants`, `Concurrency / State` |

---

## 1. Scenario & Problem Overview

Describe the real-world engineering context of the repository and why the team is touching this module today.

### Quick Workspace Setup
```bash
git clone https://github.com/owner/repo.git interview-workspace
cd interview-workspace
# Optional: git checkout <commit-sha-or-tag>
rm -rf .git && git init && git add . && git commit -m "Initial interview baseline"
```

---

## 2. Candidate Instructions (The 4-Checkpoint Flow)

> **Copy and share this section with the candidate (or use it for self-practice before reading sections 3–5).**

### Background
Summarize the domain rules and what the module is supposed to do.

### Your Tasks (Checkpoints)
1. **Checkpoint 1 — Explore & Trace (`~10 mins`)**:
   - Explore the target files and trace how data flows from entry point to output.
   - Run the existing test suite and uncomment any disabled/commented unit tests.
2. **Checkpoint 2 — Diagnose & Fix Seeded/Existing Bugs (`~15 mins`)**:
   - Identify why the failing/uncommented tests break (or where the existing implementation violates the domain specification) and fix the root cause without breaking existing callers.
3. **Checkpoint 3 — Implement Core Feature / Production Optimization (`~20 mins`)**:
   - Implement the new requirement or scale optimization so that both toy fixtures and production-scale workloads pass within constraints.
4. **Checkpoint 4 — Edge Cases, Regression Check & Solution Defense (`~15 mins`)**:
   - Add unit tests covering boundary conditions and explain why your solution is correct, what assumptions the AI made that you had to override, and any architectural trade-offs.

---

## 3. Seeded Bugs & The "AI Trap" (Confidential — HR & Interviewer View)

### Existing / Seeded Bug Manifest
- **Bug 1 (`path/to/file:line`)**: What is broken and why.
- **Bug 2 (`path/to/file:line`)**: How it interacts with Bug 1 or the new feature.

### Why Naive Copy-Paste Prompting Fails (The AI Trap)
Explain what happens when a candidate dumps the entire prompt into an LLM (GPT/Claude/Gemini) and blindly accepts the generated diff:
- **Hallucination / Broken Invariant**: ...
- **Hidden Scale / Concurrency Failure**: ...

---

## 4. Reference Divide-and-Conquer Prompt Walkthrough

How a high-performing engineer orchestrates AI on this case using **`Understand → Plan → Prompt → Review → Test`**:

1. **Step 1 (Understand — Map Structure & Trace Flow)**:
   > *"Read `file_a` and `file_b`. Do not write code yet. Trace the execution flow of `func_x()` and list all state mutations and assumptions."*
2. **Step 2 (Plan — Lock Scope, Design & Target Files)**:
   - Candidate identifies exact files and invariants before asking AI to edit.
3. **Step 3 (Prompt — Incremental Micro-Changes)**:
   > *"In `file_a`, update only `helper_y()` to handle [specific condition] while preserving [invariant]. Show a minimal diff."*
4. **Step 4 (Review — Audit Diff, Question Assumptions & Run Tests)**:
   - Candidate spots and corrects AI assumption `X` and runs the test suite.
5. **Step 5 (Test — Edge Cases, Regression Risk & Defense)**:
   - Candidate writes targeted edge-case tests and explains the end-to-end guarantee.

---

## 5. HR & Interviewer Evaluation Key (The 7 Criteria)

| Criterion | Green Flags (Score 3–4: Hire / Strong Hire) | Red Flags (Score 1–2: No Hire / Blind Vibe-Coder) |
| :--- | :--- | :--- |
| **1. Problem Decomposition** | Splits bugfix from feature implementation; isolates module boundaries first. | Pastes all 4 checkpoints into a single mega-prompt. |
| **2. Prompt Context Quality** | Feeds exact file paths, type signatures, and invariants into prompt. | Gives vague prompts ("fix the tests and implement the solver"). |
| **3. Not Blindly Trusting AI** | Catches the AI Trap in diff review; questions AI assumptions before applying. | Applies AI code without reading it; surprised when tests fail. |
| **4. Code Reading Speed** | Quickly maps entry point → core logic → test harness within 10 minutes. | Cannot explain what existing functions do without asking AI repeatedly. |
| **5. Bug & Edge-Case Discovery** | Pinpoints root cause and proactively tests empty, duplicate, or scale boundaries. | Fixes symptoms with hacky `if` branches instead of fixing root cause. |
| **6. Testing Before Claiming Done** | Runs test suite after every micro-change; adds new regression tests. | Claims "done" as soon as AI generates code without running tests. |
| **7. Explaining Why Solution Is Correct** | Clearly articulates complexity, invariants preserved, and trade-offs. | Says "the AI wrote it this way and the tests pass." |
