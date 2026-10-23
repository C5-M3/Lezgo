# 0007. Issue, branch, pull request and review workflow

- Status: Accepted
- Date: 2026-10-22
- Deciders: Nathan Sudiara

## Context

Tasks are planned in the GitHub Project "Project Management" (#1, org `C5-M3`). Humans and agents need the same path from a task to merged code, with a person checking every change.

## Decision

We will work in this order: convert the project's draft item to an issue (or create one), create the branch from the issue with `dev` as its base, pull `dev` before starting, open a pull request into `dev` using `.github/pull_request_template.md`, and merge only after a reviewer approves. Nobody merges their own pull request.

## Alternatives considered

- **Pushing straight to `dev`:** faster, but no review, and AI-written code would reach the team unchecked.
- **Pull requests without issues:** loses the link between the plan in the GitHub Project and the code.

## Consequences

- Every change is reviewed, which slows merging but catches problems early.
- `Closes #N` only auto-closes an issue when the PR merges into the default branch (`main`), so issues merged into `dev` are closed by hand or by a project workflow.
- While the project was being set up, setup work was committed straight to `main` with the user's approval; feature work follows this workflow.
- See AGENTS.md "Workflow for every task".
