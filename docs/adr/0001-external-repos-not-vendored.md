# ADR 0001 — Reference external repositories instead of vendoring code

## Status

Accepted.

## Context

Interview cases need real multi-file codebases. Vendoring 30 repos would bloat git history and stale quickly. Candidates need a clean-room workspace.

## Decision

Each case links to a public GitHub repository and provides clone + `.git`-strip provisioning steps. No vendored source lives in this hub.

## Consequences

- Workspace setup takes ~2 minutes per session.
- Cases depend on upstream availability; `scripts/check-external-repos.ts` guards reachability in CI.
- Tag/commit pinning is used where available; otherwise a documented default-branch checkout is used.
