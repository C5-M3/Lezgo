# 0002. SwiftUI and SwiftData on iOS 27

- Status: Accepted
- Date: 2026-10-22
- Deciders: Nathan Sudiara

## Context

Lezgo is a new iPhone app with no existing code or users on older iOS versions. The project was created with Xcode 27.1, which defaults to iOS 27, SwiftUI, SwiftData, `MainActor` default isolation and approachable concurrency.

## Decision

We will build the UI with SwiftUI, store data with SwiftData, target iOS 27.0 and later, and keep the Xcode 27 concurrency defaults. Third-party dependencies are added only after the team agrees.

## Alternatives considered

- **UIKit:** more code for the same screens, and the agent skills and AGENTS.md rules are written for SwiftUI.
- **Core Data:** mature but verbose; SwiftData covers our needs with less code and works directly with SwiftUI.
- **A lower deployment target:** reaches more devices but blocks the newest SwiftUI and SwiftData APIs. With no existing users, we keep the newest APIs.
- **Third-party libraries by default:** each one is a supply-chain risk and a maintenance cost, so they need a reason.

## Consequences

- Only devices on iOS 27 or later can install the app.
- Code can use the newest APIs without availability checks.
- See AGENTS.md "Project snapshot" and "Swift and SwiftUI rules".
