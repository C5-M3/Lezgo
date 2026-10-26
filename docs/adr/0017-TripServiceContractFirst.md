# 0017. Trip service contract first, with an in-memory service

- Status: Proposed
- Date: 2026-10-26
- Deciders: Nathan

## Context

Four developers build four screens in parallel (AGENTS.md, "Who owns which screen"), and every screen reads or changes the same trip: its route, its members, its status and each car's position. The release is on 30 October.
The shared models (#64) and `TripService` (#65) were planned for days 1 and 2 but are not merged, so screens have started to define their own types (`Participant` with `name` and `isLeader` in the Trip Room branch, `RoutePoint` in the Set Route branch). Those types disagree with `specs/UserStories.md` and with each other, and joining the screens later would mean rewriting them.
The CloudKit implementation (ADR 0014) needs a configured container, signed-in iCloud accounts and real phones to test, and it is not ready yet. Screens cannot wait for it.

## Decision

We will merge the data **contract** first and build the CloudKit implementation behind it:

- **Shared models** in `Lezgo/Models/`, exactly as in `specs/UserStories.md` → "Data model".
- **One `TripService` protocol** with every operation the screens need: create, join, fetch, live updates, start, remove, hand over, exit, end, location, alerts, checkpoints, route and profile. Operations take plain models and throw `TripServiceError`.
- **`InMemoryTripService`**, a complete implementation that keeps trips in memory. Previews, `DebugScreen`, unit tests and the app itself (until `LiveTripService` lands) use it, so every screen runs end to end without iCloud.
- **Environment injection.** The app root puts one service into `@Environment(\.tripService)`. A view reads it and passes it to its view model's initializer; view models never read the environment. Replacing the in-memory service with `LiveTripService` is a one-line change in `LezgoApp`.

## Alternatives considered

- **Each screen keeps its own types until CloudKit is ready:** no waiting, but every screen is rewritten at integration, in the last days before release, which is the riskiest time.
- **Wait for `LiveTripService` before building screens:** one set of types, but screens stall for days, and nobody can run a screen without two iCloud accounts and real phones.
- **Pass services through every initializer from the app root:** the most explicit, but every screen in between must carry services it does not use, and each new service changes all of them.
- **A global singleton:** the least code, but tests and previews cannot swap it safely, and it hides which screens depend on it.

## Consequences

- Screens build on the real models and the real API today. Their owners delete their own copies (`Participant` in Trip Room, `RoutePoint` in Set Route) and use the shared types.
- The `InMemoryTripService` tests describe how every operation behaves. `LiveTripService` must pass the same behaviour, so the tests double as its specification.
- Changing the protocol affects every screen: announce the change to the team and update both implementations in the same PR (AGENTS.md, "Who owns which screen").
- The in-memory service keeps each phone's trips to itself, so the app cannot sync between phones until `LiveTripService` lands (ADR 0014).
- [Architecture: MVVM, layer first](../../AGENTS.md#architecture-mvvm-layer-first) keeps the rule that view models receive services through their initializer.
