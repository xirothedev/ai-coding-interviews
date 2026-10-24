# Project Governance & Quality Standards

This document outlines how the **AI Coding Interviews** knowledge base is maintained, how new interview cases are reviewed, and the quality bar required for merging contributions.

---

## Core Design Principles

1. **Wiki & Curated Hub Architecture (No Bloated Vendor Code)**
   - Like [`codecrafters-io/build-your-own-x`](https://github.com/codecrafters-io/build-your-own-x) and [`adithya-s-k/AI-Engineering.academy`](https://github.com/adithya-s-k/AI-Engineering.academy), this repository is a **structured Markdown knowledge base**.
   - Instead of inventing toy codebases from scratch or vendoring gigabytes of source code, every case points to a **real, battle-tested open-source GitHub repository** (pinned to a specific tag or commit SHA where available; otherwise a documented default-branch checkout) and wraps it with a 4-Checkpoint interview specification, AI Trap analysis, and 7-Criteria HR Rubric.

2. **Evaluating Engineering Judgment, Not Prompt Copy-Pasting**
   - A valid AI-enabled interview case **must not** be solvable by pasting the problem statement into an LLM and blindly accepting the first output.
   - Every accepted case must document at least one verified **"AI Trap"**—an architectural invariant, scale bottleneck, concurrency hazard, or edge case where unguided LLM output produces plausible-looking but broken code.

3. **Alignment with the 7 Evaluation Criteria**
   - Every case must give the candidate an opportunity to demonstrate all 7 core competencies:
     1. Problem Decomposition (_Divide & Conquer_)
     2. Prompt Context & Precision
     3. AI Skepticism & Diff Verification (_Not Blindly Trusting AI_)
     4. Unfamiliar Codebase Navigation Speed
     5. Bug & Edge-Case Discovery
     6. Testing Before Claiming Done
     7. Explaining Why the Solution Is Correct

4. **Polyglot Inclusivity**
   - We actively curate cases across **Python, TypeScript/JavaScript, Go, Java, Rust, and C#** so engineering organizations of any stack can run standardized interviews.

---

## Curation & Review Process

1. **Proposal**: Contributors open a Pull Request or Issue using [templates/CASE_TEMPLATE.md](templates/CASE_TEMPLATE.md).
2. **Verification by Maintainers**:
   - Is the target GitHub repository public, actively accessible, and quick to run locally (`< 2 minutes` from clone to running unit tests)?
   - Are the **4 Checkpoints** (_Explore & Trace → Fix Bug → Implement Feature/Scale → Edge Cases & Defense_) realistic within a 45–75 minute window?
   - Is the **AI Trap** reproducible with frontier models (GPT, Claude, Gemini) when given a naive copy-paste prompt?
   - Does the **HR Rubric** clearly distinguish a _Blind Vibe-Coder (Score 1–2)_ from a _Strategic AI Orchestrator (Score 3–4)_?
3. **Merge & Indexing**: Once approved, the case is added to the appropriate tier (`cases/easy/`, `cases/medium/`, or `cases/hard/`) and indexed in the root [README.md](README.md).
