# 0026. Manual workflow that promotes trunk branches without a pull request

- Status: Proposed
- Date: 2026-11-10
- Deciders: Nathan Sudiara

## Context

Code moves from `dev` to `staging` to `main` ([0005](0005-TrunkBranchesAndConventionalBranch.md)). Until now each promotion was a pull request that waited for a reviewer. Everything in `dev` was already reviewed in its feature pull request, so the second review found nothing new and delayed TestFlight builds.

`staging` is promoted only when a feature needs TestFlight testing, and `main` only for a release, so a person must decide when. The ruleset on the trunk branches blocks force pushes and requires the Secret Scan, XCSSET Malware Scan and SwiftLint checks.

## Decision

We will promote with a `Promote` workflow that runs only when someone starts it (`workflow_dispatch`). The person picks `staging`, `main` or `staging-and-main`, and the workflow moves the target branch forward to the source branch's commit (a fast-forward), with no pull request and no second review. It refuses to run when the required checks did not pass on that commit, and it never force-pushes.

This is the one exception to "never push directly to a trunk branch". Feature work still reaches `dev` only through a reviewed pull request.

## Alternatives considered

- **Keep a pull request for every promotion:** a second review of code that was already reviewed; this is the delay we want to remove.
- **Open the pull request from the workflow and merge it at once:** adds a merge commit to the target that the source does not have, so the branches drift apart and the next promotion needs a merge again.
- **Promote on every push to `dev`:** sends work to TestFlight that nobody asked to test yet.
- **Force-push the target branch:** can delete a hotfix that exists only on `staging` or `main`, and the ruleset blocks it.

## Consequences

- After a promotion, `staging` (or `main`) points to the same commit as its source. Xcode Cloud builds the exact commit that was reviewed and checked in `dev`.
- A fast-forward only works when the target has no commits of its own. After a hotfix on `staging` or `main`, merge `main` back into `dev` with a pull request first; the workflow stops and says so. The same one-time merge is needed before the first run, because earlier promotion pull requests left merge commits on `staging` and `main`.
- Anyone with write access can start a promotion, including to `main`. The feature review in `dev` is the only review, so it must stay strict.
- The workflow needs `contents: write`, the first write permission in our workflows. GitHub's built-in token may not move a branch over commits that change files in `.github/workflows`; for those promotions a `PROMOTE_TOKEN` secret (a token with contents and workflows write access) is needed.
- A promotion made with the built-in token does not start GitHub Actions on the target branch. Nothing is lost: the same commit already passed the checks on its source branch.
- See AGENTS.md "Branches" and "Continuous integration".
