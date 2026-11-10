# 0025. Manual workflow that opens promotion pull requests

- Status: Proposed
- Date: 2026-11-10
- Deciders: Nathan Sudiara

## Context

Code moves from `dev` to `staging` to `main` through pull requests ([0005](0005-TrunkBranchesAndConventionalBranch.md)). Opening a promotion pull request is done by hand: pick the right base and head on the compare page and type a title that passes the pull request rules. It is easy to pick the wrong branches or a title the checks reject.

`staging` is promoted only when a feature needs TestFlight testing, and `main` only for a release, so a person must decide when. GitHub Actions is used only for fast Linux checks on the source ([0011](0011-XcodeCloudAndGitHubActions.md)).

## Decision

We will add a `Promote` workflow that runs only when someone starts it (`workflow_dispatch`). The person picks the target, `staging` or `main`, and the workflow opens the pull request from `dev` or `staging` with a title that follows the rules. It only opens the pull request: review and merge stay manual, and Xcode Cloud still builds after the merge.

## Alternatives considered

- **Open the pull request on every push to `dev`:** promotes work nobody asked to test yet, and keeps a pull request open all the time.
- **Merge or push to the trunk branch from the workflow:** skips review and breaks the rule that nobody pushes to a trunk branch.
- **A bookmarked compare link with the title filled in:** needs no setup, but each person must keep their own link, and it does not cover both targets in one place.
- **A third-party "create pull request" action:** adds a dependency to pin and review; the `gh` command that is already on the runner does the same job.

## Consequences

- The workflow needs `pull-requests: write`, the first write permission in our workflows. An admin must turn on "Allow GitHub Actions to create and approve pull requests" in the repository's Actions settings, or the run fails.
- A pull request opened by the workflow's built-in token does not start `Pull Request Checks`. The required checks (Secret Scan, XCSSET Malware Scan, SwiftLint) already ran when the head commit was pushed to `dev` or `staging`, so they still show on the pull request. The workflow sets the branches and the title itself, so the skipped branch, title and commit rules cannot be wrong there.
- The pull request is opened by `github-actions`, so the person who started the run may approve it. Keep the habit of asking a teammate to review.
- See AGENTS.md "Continuous integration".
