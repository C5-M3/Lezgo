# 0016. User stories in the repository

- Status: Accepted
- Date: 2026-10-26
- Deciders: Nathan

## Context

The user stories (`UserStories.md`) hold the rules, the copy, the data model and the Gherkin scenarios for US-01 to US-07. They were shared outside Git, and `.gitignore` blocked the `tasks/` folder that held them.
The GitHub issues point to `tasks/UserStories.md` for fields and copy ("the fields from 'Data model' in `UserStories.md`"), but that path does not exist in the repository. Teammates without the file and AI agents, which only read the repository, cannot see the data model. Screens have started to define their own models: the Trip Room branch has a `Participant` with `name`, `description` and `isLeader`, while the story stores `displayName`, `carDescription` and keeps the leader only in `Trip.leaderParticipantID`.
The team works by screen in parallel, so every screen must build on the same model and copy before the screens are joined.

## Decision

We will keep the user stories in the repository at `specs/UserStories.md` as the single source of truth for rules, copy and the data model, and change them only through pull requests. The task backlog (`tasks/`) and the lo-fi images (`context/`) stay outside Git.

## Alternatives considered

- **Keep sharing the file outside Git:** no change, but people and agents keep working from different or missing copies, which is how the `Participant` mismatch happened.
- **Copy each story into its GitHub issue:** readable on GitHub, but agents working in the repository still cannot see it, and the copies drift apart when a rule changes.
- **Keep the path `tasks/UserStories.md`:** the issue links would work unchanged, but `tasks/` reads as a to-do list and also holds the backlog and old drafts that we do not want in Git.
- **Put it in `docs/`:** `docs/` holds only architecture decision records, and mixing product specs into it hides both.

## Consequences

- Everyone, people and agents, reads the same rules and the same data model. Models and copy follow `specs/UserStories.md` word for word.
- A change to a rule, a field or a line of copy is a pull request that the team reviews, in the same PR as the code that needs it.
- The issues point to `specs/UserStories.md`. The backlog stays in the GitHub Project and in local `tasks/` files.
- [Project context](../../AGENTS.md#project-context) in AGENTS.md points to the specs.
