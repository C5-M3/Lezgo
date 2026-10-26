# 0015. Per-developer signing settings

- Status: Proposed
- Date: 2026-10-26
- Deciders: Nathan Sudiara

## Context

Every developer on the team has their own individual Apple Developer Program membership. An individual membership cannot add other developers to its team, so the team cannot share one signing team.
The project hard-codes Nathan's team (`K64G2J8QL7`), the bundle identifier from [0013](0013-AppNameAndBundleIdentifier.md) and the iCloud container from [0014](0014-CloudKitPublicDatabaseForTripSync.md). Bundle identifiers and iCloud containers are unique across all of Apple and belong to the team that registered them, so no one else can sign a build that uses them.
Today a teammate has to change the team and bundle identifier in `project.pbxproj` and the container in `Lezgo.entitlements`. Those are tracked files, so the edits end up in pull requests and every developer's change conflicts with the others. Xcode Cloud ships TestFlight builds from Nathan's account and must keep Nathan's identifiers.

## Decision

We will read the signing team and the bundle identifier prefix from `Config/Base.xcconfig`, which holds Nathan's values and optionally includes a git-ignored `Config/Local.xcconfig` where each developer sets their own. The iCloud container and the URL type name are derived from the bundle identifier, so they follow it automatically.

## Alternatives considered

- **Each developer edits the project and does not commit it:** no setup, but the edits are easy to commit by mistake and block switching branches. This is the problem we have today.
- **One shared Apple Developer team:** the cleanest setup, but it needs an organization membership (a D-U-N-S number and a paid account in a company's name), which the team does not have.
- **Separate build configurations or schemes per developer:** works without a local file, but every developer's identifiers live in the shared project and change it each time someone joins.

## Consequences

- A developer builds on their own account by copying `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and setting their team and prefix. No tracked file changes. Without the local file, the build uses Nathan's identifiers, which is what Xcode Cloud needs.
- Each developer's build uses its own CloudKit container (`iCloud.<prefix>.Lezgo`) with its own public database. Phones running different developers' builds cannot see each other's trips, so tests with several phones must all run one build, normally the TestFlight build from Xcode Cloud.
- Each developer's container has its own schema. Schema changes are made in `CloudKit/Schema.ckdb` (see 0014), imported into each developer's container, and deployed to production only from Nathan's container.
- Code must never hard-code the container identifier: use `CKContainer.default()`, which reads it from the entitlements.
- Release identifiers stay as decided in 0013. [Signing on your own account](../../AGENTS.md#signing-on-your-own-account) turns this into day-to-day rules.
