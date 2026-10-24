# Plan: Align Case Content with Real-PR Test Requirements

## Goal

Make Medium/Hard cases reference real merged PRs (done in commit 6c23bbe/4530982).
Next: ensure Section 1/3/4/5 and "Failing Tests to Enable" reflect the actual PR diff
and the tests that fail on Base SHA / pass on Merge SHA.

## Scope

- 20 cases: M01–M10, H01–H10.
- Easy tier untouched.
- Files: cases/en/{medium,hard}/*.md + vi counterparts.

## Per-Case Work (repeat for each case)

1. Fetch PR diff: `gh pr diff <N> --repo <repo>` (save to scratchpad, not repo).
2. Identify changed test files and the specific test names that fail on Base SHA.
3. Clone repo, checkout Base SHA, run `<TEST_COMMAND>` → capture failing test list.
4. Checkout Merge SHA → confirm same tests pass.
5. Edit case:
   - Section 1 "Failing Tests to Enable": list exact test names/files (interviewer-facing only).
   - Section 3 AI Traps: derive 2–3 traps from actual diff (naive approach vs correct fix).
   - Section 4 Prompt Flow: reference real files/functions (interviewer-facing only).
   - Section 5 Rubric: adjust green/red flags to the real bug.
6. Mirror Section 1/3/4/5 changes to vi counterpart (Section 2 stays translated).
7. Commit per tier or per case.

## Phase Order

- Phase A: Fetch diffs + identify failing tests (all 20) — can be parallelized with subagents.
- Phase B: Edit Sections 3/4/5 + failing tests list (all 20).
- Phase C: Reproducibility spot-check (clone/run for M04, H01, H06 at minimum).
- Phase D: Vi parity update.
- Phase E: `bun test`, wiki dry-run, check:repos, commit.

## Notes

- Never put filenames/paths/line numbers in Section 2 (Candidate Instructions) — test enforces this.
- Keep 7-criteria rubric structure; only adjust flags.
- Issue summaries must stay paraphrased (no PR/issue links) in Section 2.
- H10 is a synthetic AI-slop rescue; its real PR (getlago/lago #820) is unrelated —
  consider skipping H10 or replacing with a more relevant PR.

## Status

- [x] Section 1 real-PR metadata added (BASE_SHA/MERGE_SHA/TEST_COMMAND/clean-room steps).
- [ ] Section 3/4/5 aligned to real PR diffs.
- [ ] Failing-tests list concrete.
- [ ] Vi parity for Sections 3/4/5.
