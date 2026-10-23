# Contributing to AI Coding Interviews

Thank you for helping build the open-source knowledge base for **AI-Enabled Software Engineering Interviews**!

Whether you are an **Engineering Manager**, **HR / Talent Acquisition Specialist**, **Staff/Principal Engineer**, or an **Interview Candidate** who just practiced a case, your contributions make technical hiring and training fairer, more realistic, and higher-signal.

---

## Ways You Can Contribute

### 1. Propose a New GitHub-Backed Interview Case

We do **not** invent synthetic codebases from scratch or commit third-party source code into this repo. Instead, we curate **real, well-tested open-source GitHub repositories** and wrap them into structured 60-minute interview blueprints.

To add a new case:

1. Copy [`templates/CASE_TEMPLATE.md`](templates/CASE_TEMPLATE.md).
2. Choose the target difficulty tier:
   - **Easy (`cases/easy/`)**: 3–4 files, 1–2 localized bugs, 1 clear AI trap, polyglot katas or small utilities (~30–45 min).
   - **Medium (`cases/medium/`)**: 5–7 files across modules, 2–3 interacting bugs, multi-stage feature/scale extension (~45–60 min, Meta/Canva standard bar).
   - **Hard (`cases/hard/`)**: 7–10+ files, real production open-source repository commits (`SWE-bench` / `Multi-SWE-bench` style), compounding AI traps involving cross-file invariants, concurrency, scale divergence, or AI-slop rescue (~60–75 min, Senior/Staff bar).
3. Test your case against at least one frontier LLM (e.g., Claude, GPT, Gemini) using a naive "copy-paste the whole prompt" approach to verify and document the **AI Trap**.
4. Add your case to the tier catalog and update the master table in [`README.md`](README.md).

### 2. Add a Language Variant to an Existing Case

Many cases can be run across **Python, TypeScript, Go, Java, Rust, and C#**. You can contribute by:

- Linking an equivalent open-source GitHub repository (or polyglot folder path) for an additional language.
- Documenting the exact test runner command (`pytest`, `npm test`, `go test ./...`, `mvn test`, `cargo test`) and target file paths for that language.

### 3. Document New "AI Traps" & Model Failure Modes

As frontier LLMs evolve, old traps may become easier while new failure modes emerge (e.g., over-mocking in tests, subtle async race conditions, mutating shared caches).

- Submit updates to the **AI Trap Analysis** section of any case when you observe how candidates or models fail in practice.

### 4. Improve Prompt Templates & HR Rubrics

- Refine the pre-written prompts in [`docs/02-EMPLOYEE-MINDSET-AND-PROMPT-PLAYBOOK.md`](docs/02-EMPLOYEE-MINDSET-AND-PROMPT-PLAYBOOK.md).
- Add calibration examples, red/green flags, or debrief questions in [`docs/01-THE-7-EVALUATION-CRITERIA.md`](docs/01-THE-7-EVALUATION-CRITERIA.md) and [`docs/03-HR-AND-INTERVIEWER-RUNBOOK.md`](docs/03-HR-AND-INTERVIEWER-RUNBOOK.md).

---

## Quality Checklist for Every Case Contribution

Before opening a Pull Request, verify that your case includes:

- [ ] **Real Open-Source GitHub Repository Link**: Publicly accessible, with fast local unit tests (`< 2 minutes` setup time).
- [ ] **4 Sequential Checkpoints** (Meta AI-Enabled SWE Format):
  1. _Checkpoint 1: Explore & Trace_ (Map architecture & run/uncomment tests)
  2. _Checkpoint 2: Bugfix_ (Diagnose and fix existing/seeded bug)
  3. _Checkpoint 3: Core Feature / Optimization_ (Implement solver, feature, or production-scale improvement)
  4. _Checkpoint 4: Edge Cases & Defense_ (Handle the trap edge case and explain trade-offs)
- [ ] **Verified AI Trap**: Concrete explanation of what happens if a candidate blindly pastes the requirement into an LLM without decomposing the problem.
- [ ] **Divide-and-Conquer Prompt Walkthrough**: Example sequence following `Understand → Plan → Prompt → Review → Test`.
- [ ] **7-Criteria HR Grading Key**: Specific Green Flags and Red Flags for interviewers.
- [ ] **100% English Documentation**: Clear, concise GitHub-Flavored Markdown.

---

## Local Quality Checks, Pre-Commit Hooks & Commit Conventions

This repository uses **[Bun](https://bun.sh)** (`>= 1.4.4`), **Husky**, **`lint-staged`**, and **`commitlint`** to enforce formatting, type checking, link/rubric integrity, and Conventional Commits automatically before every commit and pull request:

```bash
# Install devDependencies and activate Husky git hooks (.husky/pre-commit & .husky/commit-msg)
bun install

# Format Markdown, YAML, JSON, and TypeScript files natively with Bun
bun run fmt

# Verify formatting without modifying files
bun run fmt:check

# Run native Bun TypeScript type checking
bun run check

# Run the repository integrity test suite (30-case rubric verification, relative link checker, and Wiki dry-run)
bun test
```

### Commit Message Format (Conventional Commits)

All commit messages are validated by `commitlint` via `.husky/commit-msg` and must follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

- `feat(cases): add H11 distributed lock case`
- `docs(playbook): clarify verification prompts in step 5`
- `fix(links): update broken repository link in M04`
- `ci(workflows): update weekly external repo check schedule`

---

## Submitting a Pull Request

1. Fork the repository and create a descriptive branch (`feat/case-hard-rate-limiter` or `docs/update-prompt-playbook`).
2. Follow the structure in [`templates/CASE_TEMPLATE.md`](templates/CASE_TEMPLATE.md).
3. Run `bun run fmt && bun run check && bun test` locally.
4. Open a Pull Request and complete the checklist in [`.github/PULL_REQUEST_TEMPLATE.md`](.github/PULL_REQUEST_TEMPLATE.md).
