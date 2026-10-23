# 0013. App name Lezgo and bundle identifier

- Status: Accepted
- Date: 2026-10-22
- Deciders: Nathan Sudiara

## Context

The project started from Xcode's template as `MainProject`. The team chose the app's name before anything was registered in App Store Connect or Xcode Cloud, so renaming was still free.

## Decision

We will name the app, Xcode project, target, scheme and GitHub repository `Lezgo` (`C5-M3/Lezgo`), with bundle identifier `com.nathansudiara.Lezgo`. Test targets use `com.nathansudiara.LezgoTests` and `com.nathansudiara.LezgoUITests`.

## Alternatives considered

- **Keeping `MainProject`:** says nothing about the app.
- **Keeping the old bundle identifier:** only useful if an App Store Connect record already existed, which it did not.

## Consequences

- The bundle identifier cannot change once the App Store Connect record is created. Switching to an organization prefix must happen before then and needs a new record superseding this one.
- GitHub redirects the old repository URL, but clones should update their remote to `https://github.com/C5-M3/Lezgo.git`.
