# 0003. MVVM with layer-first folders

- Status: Accepted
- Date: 2026-10-22
- Deciders: Nathan Sudiara

## Context

The team needs one structure that every person and agent follows, so code is easy to find and logic can be tested without the UI.

## Decision

We will use MVVM. Each screen is a `<Name>View` with a `<Name>ViewModel` (`@Observable final class`). Services sit behind protocols and are passed into view models through their initializer. Folders are grouped by layer: `App/`, `Models/`, `ViewModels/`, `Views/Screens/`, `Views/Components/`, `Services/`, `Extensions/`, `Resources/`.

## Alternatives considered

- **Feature-first folders (one folder per feature):** keeps a feature's files together, but the team chose layer-first so each layer has one obvious home and shared code is easy to spot.
- **Plain SwiftUI with logic in views:** less code, but the logic cannot be unit tested, which conflicts with TDD ([0008](0008-TestDrivenDevelopment.md)).
- **The Composable Architecture (TCA):** strong structure, but a third-party dependency and a steep learning curve for the team ([0002](0002-SwiftUIAndSwiftDataOnIOS27.md)).

## Consequences

- View models are unit tested with fake services; views stay thin.
- A feature's files are spread across several folders.
- Git does not keep empty folders, so a layer folder appears when its first file is added.
- See AGENTS.md "Architecture: MVVM, layer first".
