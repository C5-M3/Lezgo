# 0035. The app version comes from a release tag that Promote creates

- Status: Accepted
- Date: 2026-11-19
- Deciders: Nathan Sudiara

## Context

Every App Store release needs a higher version number (`MARKETING_VERSION`, shown on the App Store as "Version 1.0.1"). Apple closes a version number once it is approved: App Store Connect then rejects new uploads with that number, including TestFlight builds from `staging`. Until now the number was changed by hand in 8 build settings in `project.pbxproj` (app, widget extension, unit tests, UI tests; Debug and Release), in its own pull request, before every release (#365). The widget extension must carry the same number as the app, or the upload fails.

The build number (`CURRENT_PROJECT_VERSION`) is already set by Xcode Cloud on every build.

Releases reach `main` only through the `Promote` workflow ([0026](0026-ManualPromotionWorkflow.md)), which fast-forwards `main` to a commit that already passed its checks in `dev`. A commit made by the workflow itself would exist only on `main`, and the next fast-forward would stop because the branches diverged.

The person who starts a release knows what kind of release it is. We follow [Semantic Versioning](https://semver.org): a fix raises the last number, a new feature the middle one, a big update the first one.

## Decision

We will set the version from a git tag. When `Promote` moves `main`, the person picks **fix**, **feature** or **big update**. The workflow reads the latest `vX.Y.Z` tag, works out the next number (1.0.1 becomes 1.0.2, 1.1.0 or 2.0.0), tags the promoted commit with it, and only then moves `main`. An Xcode Cloud script (`ci_scripts/ci_post_clone.sh`) reads the tags before building and writes the version for every target into a git-ignored `Config/CI.xcconfig`:

- On `main`: the tag on the commit being built. With no tag the build stops, so a release can never ship under an old number.
- On `staging` and `dev`: the next fix number after the latest tag (after `v1.0.1`, TestFlight builds say 1.0.2), so internal builds are never rejected for a closed number.

`MARKETING_VERSION` is removed from `project.pbxproj` and set once in `Config/Base.xcconfig`, which only local builds use. Nobody edits the version by hand any more.

## Alternatives considered

- **Keep editing the number by hand:** one pull request and 8 edits per release, and a release is blocked when someone forgets it. This is what we want to remove.
- **Let Promote commit the new number:** the commit exists only on `main`, so `main` and `dev` diverge and the next promotion fails; pushing it to `dev` instead skips the reviewed pull request that the trunk ruleset requires.
- **One line in `Config/Base.xcconfig`, still by hand:** removes the 8 edits but still needs a pull request and memory before every release.
- **A GitHub Action that bumps the number after each App Store release:** needs an App Store Connect API key as a secret, and it can only guess the kind of the next release.

## Consequences

- A release is one action: run `Promote` to `main` and pick fix, feature or big update. The tag (`v1.0.2`) also records which commit each App Store version came from.
- The version is no longer visible in the code. Read it from the latest tag (`git describe --tags --abbrev=0`) or the Promote run summary.
- Promoting `main` with nothing new does not create a tag. Running it again after a failure reuses the tag already on that commit instead of skipping a number.
- The first tag, `v1.0.0`, marks the commit of the 1.0 release (`b46f274`). The 1.0.1 pull request (#366) is closed in favour of this one: the next fix release becomes 1.0.1 automatically.
- `ci_scripts/ci_post_clone.sh` is a build script that Xcode Cloud runs before every build. `Scripts/ScanForXcsset.sh` warns about it, as it warns about every script, so reviewers read every change to it.
- Xcode Cloud must be able to fetch the tags. If the first build cannot, the script fails on `main` with a clear message instead of guessing.
- The Promote workflow pushes tags, which its `contents: write` permission already allows.
- See AGENTS.md "Branches" and "Continuous integration".
