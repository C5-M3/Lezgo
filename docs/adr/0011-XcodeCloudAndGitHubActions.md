# 0011. Xcode Cloud for builds, GitHub Actions for source checks

- Status: Accepted
- Date: 2026-10-22
- Deciders: Nathan Sudiara

## Context

Builds, tests and TestFlight delivery are handled by Xcode Cloud through App Store Connect. The repository is private, and GitHub bills macOS runner minutes at a much higher rate than Linux minutes.

## Decision

We will let Xcode Cloud build, test and ship the app. GitHub Actions runs only fast Linux checks on the source:

- **Security Checks:** the XCSSET malware scan and the Gitleaks secret scan.
- **Pull Request Checks:** branch, title and commit rules, plus ADR format.
- **SwiftLint:** linting in strict mode.

## Alternatives considered

- **Building and testing in GitHub Actions on macOS runners:** duplicates Xcode Cloud and costs far more for a private repository.
- **No GitHub checks:** leaves malware, secret and convention problems to manual review.

## Consequences

- Each check script has its own tests in `Scripts/Tests/`, run by the same workflow.
- A failing build or test shows up in Xcode Cloud, not on the GitHub pull request, until Xcode Cloud reports status checks back.
- See AGENTS.md "Continuous integration".
