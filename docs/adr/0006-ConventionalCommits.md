# 0006. Conventional Commits and small commits

- Status: Accepted
- Date: 2026-10-22
- Deciders: Nathan Sudiara

## Context

Commit history is how the team, reviewers and agents learn what changed and why. Large mixed commits are hard to review and hard to revert.

## Decision

We will write every commit and PR title as a [Conventional Commit](https://www.conventionalcommits.org) (`<type>(<optional scope>): <summary>`) with types `feat`, `fix`, `refactor`, `perf`, `style`, `test`, `docs`, `build`, `ci`, `ops` and `chore`. We commit and push each small logical step instead of bundling work into one big commit.

## Alternatives considered

- **Free-form messages:** no tooling needed, but history becomes inconsistent and impossible to filter by kind of change.
- **Bundled commits per feature:** fewer commits, but harder to review, bisect and revert.

## Consequences

- `Scripts/CheckPullRequestRules.sh` rejects PR titles and commits that do not follow the format. Merge and revert commits made by git are allowed.
- Changelogs can later be generated from history.
- See AGENTS.md "Commits".
