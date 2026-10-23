# 0005. Trunk branches and Conventional Branch names

- Status: Accepted
- Date: 2026-10-22
- Deciders: Nathan Sudiara

## Context

The app ships to the App Store, to external TestFlight testers, and is tested daily by developers. Each of these needs a stable source branch, and branch names should say what the work is.

## Decision

We will keep three long-lived trunk branches: `main` (App Store), `staging` (external TestFlight) and `dev` (integration). Work happens on short-lived branches named with [Conventional Branch](https://conventionalbranch.org): `feature/`, `bugfix/`, `hotfix/`, `release/` or `chore/`, then a lowercase hyphenated description with the issue number. Code flows feature → `dev` → `staging` → `main`; hotfixes may go to `main` or `staging` and come back to `dev`. Merged branches are deleted.

## Alternatives considered

- **Trunk-based development on `main` only:** simpler, but gives no stable branch for TestFlight builds separate from daily work.
- **Full git-flow:** adds long-lived release branches we do not need yet.
- **AI agent prefixes (`claude/`, `codex/`):** allowed by Conventional Branch 1.1, but we use purpose prefixes for everyone so history reads the same whoever did the work.

## Consequences

- `Scripts/CheckPullRequestRules.sh` checks branch names and which branch may target which.
- GitHub's free plan cannot protect private branches, so the flow relies on the PR check and review.
- See AGENTS.md "Branches".
