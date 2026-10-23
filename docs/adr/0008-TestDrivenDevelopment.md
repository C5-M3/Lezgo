# 0008. Test-driven development

- Status: Accepted
- Date: 2026-10-22
- Deciders: Nathan Sudiara

## Context

Much of the code is written by AI agents. Tests written first describe the expected behavior before any code exists, which keeps agents honest and gives reviewers a clear specification.

## Decision

We will follow red, green, refactor for every change: a failing test first, then the smallest code that passes, then cleanup, each in its own commit. Unit tests use Swift Testing in `LezgoTests`; UI tests use XCTest in `LezgoUITests`, only when a unit test cannot cover the behavior. The shared `Lezgo` scheme runs both.

## Alternatives considered

- **Tests after the code:** common, but tests then tend to confirm whatever the code does instead of what it should do.
- **XCTest for everything:** works, but Swift Testing is Apple's modern framework with clearer assertions and parameterized tests.
- **Mostly UI tests:** slow and fragile; logic in view models is cheaper to test directly.

## Consequences

- View models and services must be testable, which supports MVVM with injected services ([0003](0003-MvvmLayerFirst.md)).
- Tests use in-memory SwiftData containers and fake services, never the network or real data.
- Builds and tests run in Xcode Cloud, not GitHub Actions ([0011](0011-XcodeCloudAndGitHubActions.md)).
- See AGENTS.md "Test-driven development".
