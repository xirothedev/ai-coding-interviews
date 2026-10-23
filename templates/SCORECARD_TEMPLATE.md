# AI-Enabled Coding Interview — Candidate Scorecard

| Session Metadata              | Details                                                                          |
| :---------------------------- | :------------------------------------------------------------------------------- |
| **Candidate / Employee Name** |                                                                                  |
| **Role & Level Target**       | `L3 (Junior)` / `L4 (Mid)` / `L5 (Senior)` / `L6+ (Staff/Principal)`             |
| **Case ID & Title**           | e.g., `M01 — Wordle Puzzle & Solver Engine` / `H01 — Async HTTP Connection Pool` |
| **Programming Language Used** | `Python` / `TypeScript` / `Go` / `Java` / `Rust` / `C#`                          |
| **AI Tooling Used**           | `CoderPad AI` / `Cursor` / `Claude Code` / `GitHub Copilot` / `ChatGPT`          |
| **Interviewer(s) & Date**     |                                                                                  |
| **Overall Recommendation**    | `Strong No Hire (1)` / `No Hire (2)` / `Hire (3)` / `Strong Hire (4)`            |

---

## Part 1: Checkpoint Completion Gate

_Standard passing bar: Completing Checkpoints 1–3 cleanly, plus defending edge cases in Checkpoint 4 (3 to 4 out of 4 checkpoints)._

| Checkpoint                                      | Status (`Pass` / `Partial` / `Fail`) | Time Spent | Interviewer Notes                                            |
| :---------------------------------------------- | :----------------------------------: | :--------: | :----------------------------------------------------------- |
| **CP1: Explore Codebase & Run/Uncomment Tests** |                                      |   `~10m`   | Did they read tests & trace flow before editing?             |
| **CP2: Diagnose & Fix Existing/Seeded Bugs**    |                                      |   `~15m`   | Did they fix the root cause or patch symptoms?               |
| **CP3: Implement Core Feature / Scale Target**  |                                      |   `~20m`   | Did they prompt incrementally or dump the whole spec?        |
| **CP4: Edge Cases, AI Trap & Solution Defense** |                                      |   `~15m`   | Did they catch the AI Trap and explain why their code works? |

---

## Part 2: The 7 Evaluation Criteria Scorecard (1–4 Scale)

### Scoring Scale

- **1 — Blind Vibe-Coder (Strong No Hire)**: Copy-pastes requirements into AI blindly, accepts large diffs without reading, cannot explain existing code or fix AI-generated bugs.
- **2 — Over-Reliant / Reactive (No Hire)**: Uses AI via trial-and-error prompting ("it's still failing, fix it"), misses subtle bugs/traps, weak verification habits.
- **3 — Solid AI Orchestrator (Hire)**: Follows `Understand → Plan → Prompt → Review → Test`; decomposes problems cleanly, audits diffs, catches edge cases, and owns every line committed.
- **4 — Force-Multiplier Engineer (Strong Hire)**: Exceptional architectural speed; uses AI surgically to map flows and accelerate boilerplate while proactively pre-empting scale/concurrency traps and writing rigorous tests.

|   #   | Evaluation Criterion                               | Score (1–4) | Observed Evidence (Prompts Used, Diffs Rejected, Tests Run) |
| :---: | :------------------------------------------------- | :---------: | :---------------------------------------------------------- |
| **1** | **Problem Decomposition** (_Divide & Conquer_)     |    `/ 4`    |                                                             |
| **2** | **Prompt Context & Precision**                     |    `/ 4`    |                                                             |
| **3** | **AI Skepticism & Diff Review** (_No Blind Trust_) |    `/ 4`    |                                                             |
| **4** | **Unfamiliar Codebase Navigation Speed**           |    `/ 4`    |                                                             |
| **5** | **Bug & Edge-Case Discovery**                      |    `/ 4`    |                                                             |
| **6** | **Verification & Testing Before Claiming Done**    |    `/ 4`    |                                                             |
| **7** | **Explaining Why the Solution Is Correct**         |    `/ 4`    |                                                             |
|       | **AVERAGE SCORE**                                  | **`/ 4.0`** | _(Target Bar: `>= 3.0` with no `1` on Criterion #3 or #6)_  |

---

## Part 3: Instant Red Flags Observed (Check Any That Occurred)

- [ ] **Zero-Read Prompting**: Pasted problem instructions into AI before opening `src/` or running existing tests.
- [ ] **Blind Diff Acceptance**: Applied a multi-function AI code block without reading line-by-line or questioning hidden assumptions.
- [ ] **Prompt Thrashing ("Fix It" Loop)**: Pasted raw stack traces back into AI 3+ times without diagnosing the root cause themselves.
- [ ] **Test Tampering**: Modified or deleted a valid unit test assertion just to make the test suite turn green.
- [ ] **Unverified "Done" Claim**: Declared a checkpoint finished before executing the test suite or checking boundary conditions.
- [ ] **Loss of Code Ownership**: Could not explain why a specific data structure, condition, or helper generated by AI was necessary.

---

## Part 4: Written Debrief Summary

- **Strengths Demonstrated**:
- **Gaps / Risks Identified**:
- **Final Hiring / Leveling Justification**:
