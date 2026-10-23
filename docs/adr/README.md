# Architecture decision records

An architecture decision record (ADR) explains one decision: the problem, what we chose, what we rejected and what follows.
AGENTS.md holds the day-to-day rules; these records hold the reasons behind them.

## How to use them

- **Before starting a task,** read this index. Do not work against an Accepted record.
- **To change a decision,** copy `Template.md` to the next number, set the status to Proposed, and get the team's approval. When it is accepted, set the old record's status to `Superseded by NNNN`. Never rewrite an accepted record's decision.
- **Write a new record** when you add a dependency or framework, change the architecture or folder layout, go against Apple's conventions, change the workflow or CI, or make any choice that is hard to undo.
- **File names** are `NNNN-PascalCaseTitle.md`, numbered in order. Statuses are Proposed, Accepted, Deprecated or `Superseded by NNNN`.
- `Scripts/CheckDecisionRecords.sh` checks the records and this index in every pull request.

## Records

| ADR | Title | Status | Date |
| --- | --- | --- | --- |
| [0001](0001-RecordArchitectureDecisions.md) | Record architecture decisions | Accepted | 2026-10-23 |
| [0002](0002-SwiftUIAndSwiftDataOnIOS27.md) | SwiftUI and SwiftData on iOS 27 | Accepted | 2026-10-22 |
| [0003](0003-MvvmLayerFirst.md) | MVVM with layer-first folders | Accepted | 2026-10-22 |
| [0004](0004-PascalCaseFunctionNames.md) | PascalCase function names | Accepted | 2026-10-22 |
| [0005](0005-TrunkBranchesAndConventionalBranch.md) | Trunk branches and Conventional Branch names | Accepted | 2026-10-22 |
| [0006](0006-ConventionalCommits.md) | Conventional Commits and small commits | Accepted | 2026-10-22 |
| [0007](0007-IssueBranchPullRequestWorkflow.md) | Issue, branch, pull request and review workflow | Accepted | 2026-10-22 |
| [0008](0008-TestDrivenDevelopment.md) | Test-driven development | Accepted | 2026-10-22 |
| [0009](0009-AccessibilityMinimumBar.md) | Accessibility minimum bar | Accepted | 2026-10-22 |
| [0010](0010-SecurityBaseline.md) | Security baseline | Accepted | 2026-10-22 |
| [0011](0011-XcodeCloudAndGitHubActions.md) | Xcode Cloud for builds, GitHub Actions for source checks | Accepted | 2026-10-22 |
| [0012](0012-PinnedAgentSkills.md) | Pinned agent skills, installed per developer | Accepted | 2026-10-22 |
| [0013](0013-AppNameAndBundleIdentifier.md) | App name Lezgo and bundle identifier | Accepted | 2026-10-22 |
