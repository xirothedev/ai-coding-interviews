# ADR 0003 — Polyglot language support per case

## Status

Accepted.

## Context

Cases target engineers across languages. Not every source repo supports every language.

## Decision

Each case declares `Supported Languages` explicitly; only languages the source repo actually provides are listed.

## Consequences

- Language lists vary by case and must be kept accurate.
- Contributors must verify language availability before adding a case.
