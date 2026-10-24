# E06 — Build Pipeline Notification Router & Flaky Step Retry

[⬅️ Back to Easy Catalog](README.md) · [🏠 Master Hub](../../README.md)

| Attribute                    | Details                                                                                                               |
| :--------------------------- | :-------------------------------------------------------------------------------------------------------------------- |
| **Case ID**                  | `E06`                                                                                                                 |
| **Difficulty Level**         | 🟢 **Easy** (`30–45 mins` — Junior / Mid Bar)                                                                         |
| **Task Archetype**           | Code Review & AI-Slop Rescue + Refactoring                                                                            |
| **Source GitHub Repository** | [`emilybache/BuildPipeline-Refactoring-Kata`](https://github.com/emilybache/BuildPipeline-Refactoring-Kata)           |
| **Target Files**             | `build_pipeline/pipeline.py`, `build_pipeline/project.py` & `tests/test_pipeline.py` _(or `go/`, `java/`, `csharp/`)_ |
| **Supported Languages**      | `Python`, `Go`, `Java`, `C#`                                                                                          |
| **Primary AI Traps**         | Sending duplicate failure emails inside the deployment retry loop · Calling `deploy()` even when unit tests failed    |

---

## 1. Interviewer Setup & Seeded Bug Manifest (Confidential)

### Clean-Room Workspace Provisioning

```bash
git clone https://github.com/emilybache/BuildPipeline-Refactoring-Kata.git pipeline-interview
cd pipeline-interview/python # (or go / java / csharp)
rm -rf ../.git && git init && git add . && git commit -m "Initial interview baseline"
pytest
```

### Seeded Defects to Inject Before the Session

1. **Bug 1 (String Equality / Truthiness Bug in `run_tests()`)**: In `build_pipeline/pipeline.py`, seed a bug where `project.run_tests()` returning `"failure"` is checked improperly (or `tests_passed` defaults to `True` on an unexpected status string), allowing `deploy()` to run when tests failed!
2. **Commented Tests**: Comment out `test_unexpected_test_status_aborts_deploy` and `test_deploy_retry_sends_single_summary_email` in `tests/test_pipeline.py`.

---

## 2. Candidate Instructions (Copy-Paste into CoderPad / IDE)

> ### Welcome to Your AI-Enabled SWE Coding Interview
>
> You are working on a CI/CD Build Pipeline orchestrator (`BuildPipeline-Refactoring-Kata`). You have full access to the AI Assistant and test runner.
>
> ### Problem Context
>
> 1. **Fix Existing Test Status Bug**:
>    - If a project has tests (`project.has_tests()`), `project.run_tests()` must return `"success"` for tests to pass. Any other return value (`"failure"`, `"error"`, `""`) must mark the test stage as failed, log `"Tests failed"`, and **skip deployment completely**.
> 2. **New Feature — Deployment Retry Policy (`max_deploy_retries: int = 0`)**:
>    - Add `max_deploy_retries: int = 0` to `Pipeline` (or `Pipeline.run(project, max_deploy_retries=0)`):
>      - If the test stage passes, attempt `project.deploy()`.
>      - `project.deploy()` returns `"success"` on success, and any other string on failure.
>      - If `deploy()` fails and `max_deploy_retries > 0`, retry `project.deploy()` up to `max_deploy_retries` additional times (total attempts `<= 1 + max_deploy_retries`), stopping as soon as an attempt returns `"success"`.
>      - **Critical Notification Invariant**: Regardless of how many retry attempts occur, `emailer.send(...)` MUST be called **at most once per `Pipeline.run()`** (at the end of the pipeline, if `config.send_email_summary()` is enabled), reporting the final outcome (`"Deployment completed successfully"` if any retry succeeded, or `"Deployment failed"` if all retries failed)!
>
> ### Your Tasks
>
> 1. **Explore & Trace**: Inspect `build_pipeline/pipeline.py`, `build_pipeline/project.py`, and `tests/test_pipeline.py`. Run `pytest`.
> 2. **Uncomment & Fix Test Stage Bug**: Uncomment the tests in `tests/test_pipeline.py` and fix the test-stage status check.
> 3. **Refactor & Implement Deployment Retries**: Separate stage execution from logging/email notifications and implement `max_deploy_retries`.
> 4. **Verify Edge Cases**: Test `max_deploy_retries = 3` where attempt #1 and #2 fail and attempt #3 succeeds (assert `deploy()` called `3` times and `emailer.send("Deployment completed successfully")` called **exactly `1` time**!).

---

## 3. The AI Traps & Expected Solution (Confidential)

### Trap 1: Wrapping the Legacy `deploy()` + `emailer.send()` Block Inside a `for` Loop

- **What Naive AI Writes**:
  ```python
  for attempt in range(max_deploy_retries + 1):
      if project.deploy() == "success":
          self.log.info("Deployment successful")
          if self.config.send_email_summary():
              self.emailer.send("Deployment completed successfully")
          break
      else:
          self.log.error("Deployment failed")
          if self.config.send_email_summary():
              self.emailer.send("Deployment failed") # <-- BUG! Sends email on every failed retry!
  ```
- **Why It Fails**: When attempt #1 fails and attempt #2 succeeds, the user receives **two contradictory emails**: `"Deployment failed"` followed 1 second later by `"Deployment completed successfully"`!
- **Correct Fix**: Separate **Stage Execution** (`_run_test_stage`, `_run_deploy_stage_with_retries`) from **Final Summary Notification** (`_send_summary_email(tests_passed, deploy_passed)`).

---

## 4. Reference Divide-and-Conquer Prompt Flow

1. **Step 1 (`Understand`)**:
   > _"Do not write code. Trace all branches of `Pipeline.run()` in `build_pipeline/pipeline.py` and list every log message and email string emitted."_
2. **Step 2 (`Plan`)**:
   - Decouple stage execution (`tests_passed = self._run_tests(project)`, `deploy_passed = self._run_deploy(project, max_deploy_retries)`) from `_notify(tests_passed, deploy_passed)`.
3. **Step 3 (`Prompt`)** & **Step 4 (`Review`)**:
   - Verify `self.emailer.send()` is outside the retry loop and called at most once.

---

## 5. HR & Interviewer Grading Rubric (All 7 Criteria)

|   #   | Criterion                        | Strong Hire / Hire (`Score 3–4`)                                                                               | No Hire / Blind Vibe-Coder (`Score 1–2`)                                                                       |
| :---: | :------------------------------- | :------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------- |
| **1** | **Problem Decomposition**        | Refactors `Pipeline.run()` into distinct phases (Test → Deploy with Retry → Notify) before adding retry logic. | Stuffs a `for` loop inside the existing nested `if/else` pyramid.                                              |
| **2** | **Prompt Context Quality**       | Explicitly specifies that `emailer.send()` must be called at most once _after_ all retries settle.             | Prompts _"Add retry logic to `deploy()` in `pipeline.py`"_.                                                    |
| **3** | **Not Blindly Trusting AI**      | Checks whether `emailer.send` or duplicate final logs are inside the retry loop.                               | Accepts AI code that calls `emailer.send("Deployment failed")` on transient retry failures.                    |
| **4** | **Code Reading Speed**           | Maps all 4 combinations of `(has_tests, tests_passed, deploy_passed, send_email)` within 5 minutes.            | Misreads the boolean negation in the legacy `if/else` blocks.                                                  |
| **5** | **Bug & Edge-Case Discovery**    | Tests transient failure recovering on last retry, all retries failing, and `max_deploy_retries = 0`.           | Only tests when `deploy()` succeeds on attempt #1 or fails with `0` retries.                                   |
| **6** | **Testing Before Claiming Done** | Asserts exact call count `assert emailer.send.call_count == 1` and `assert project.deploy.call_count == 3`.    | Only checks `"Deployment completed successfully" in emailer.calls` without checking `len(emailer.calls) == 1`! |
| **7** | **Explaining Correctness**       | Explains Separation of Concerns (Execution State vs. Side-Effect Notification).                                | Cannot explain why coupling side effects inside retry loops is dangerous in production.                        |

### Interviewer Probing Questions (Final 10 Minutes)

1. **Q**: _"Why is asserting `'Deployment completed successfully' in emailer.messages` insufficient in a unit test for retry notifications?"_  
   **Expected Answer**: Because if the code sent `['Deployment failed', 'Deployment failed', 'Deployment completed successfully']`, an `in` assertion would still pass! You must assert `emailer.messages == ['Deployment completed successfully']` (exact list equality / call count = 1).
