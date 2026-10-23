# 0001. Record architecture decisions

- Status: Accepted
- Date: 2026-10-23
- Deciders: Nathan Sudiara

## Context

Several people and several AI agents work on Lezgo. Agents start each session without memory, so they tend to re-open questions that were already settled (architecture, naming, workflow) or quietly work against them. AGENTS.md lists the rules, but not why they exist or what was rejected.

## Decision

We will record every significant decision as an Architecture Decision Record in `docs/adr/`, using `Template.md`, listed in `docs/adr/README.md`. Accepted records are never rewritten; a changed decision gets a new record that supersedes the old one.

## Alternatives considered

- **Only AGENTS.md:** keeps the rules but loses the reasons and the rejected options, so the same debates come back.
- **A `Decisions/` folder at the repository root:** works, but `docs/adr/` is the common convention that tools and people already recognize.
- **Wiki or GitHub Discussions:** lives outside the code, so agents working in the repository do not see it.

## Consequences

- Agents read the index before starting a task and do not contradict an Accepted record.
- A change to a decision needs a new record with status Proposed and the user's approval before code changes.
- `Scripts/CheckDecisionRecords.sh` runs in Pull Request Checks and fails when a record or the index is malformed.
- Rules live in AGENTS.md; reasons live here. AGENTS.md sections link to their record.
