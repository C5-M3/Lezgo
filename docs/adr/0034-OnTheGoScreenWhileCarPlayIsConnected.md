# 0034. The iPhone shows the On the Go list while CarPlay is connected

- Status: Proposed
- Date: 2026-11-18
- Deciders: O

## Context

[0023](0023-CarPlayMirrorsTheTripMap.md) makes CarPlay mirror the trip map that is open on the iPhone. While CarPlay is connected, the car and the phone therefore draw the same map, and the driver only needs one of them.

Everything outside the screen reads the trip through `ActiveTripMap`: CarPlay, Siri and the Live Activity. `TripMapView` puts its view model there in `onAppear` and takes it out in `onDisappear`. If the phone navigated to another screen, the view model would be taken out and CarPlay would lose the trip.

The team's design for this case shows an "On the Go…" screen on the phone: a "To Next Stop" card with the time left, the list of participants (name, status and street, car, ETA), and the buttons End Trip and Edit route for the Leader or Exit Trip for a Member.

## Decision

We will show the On the Go screen on the iPhone instead of the map, only while CarPlay is connected, and keep `TripMapView` and its view model alive in both cases.

- The CarPlay scene delegate sets `CarPlaySession.isConnected` in `didConnect` and `didDisconnect`. `CarPlaySession` is a small `@Observable` class, shared the same way as `ActiveTripMap`.
- `TripMapView` chooses what to draw from `isConnected`: the map and its cards when it is `false`, the On the Go screen when it is `true`. It is the same view, so `onAppear` and `onDisappear` do not run when the content changes and `ActiveTripMap` keeps the view model.
- The On the Go screen reads the same `TripMapViewModel` and uses its existing End Trip, Exit Trip and Edit route actions. It adds no trip data of its own.
- When the cable is unplugged, the map comes back by itself.

## Alternatives considered

- **Navigate to a separate On the Go screen:** the view model would leave `ActiveTripMap` when the map disappears, so CarPlay, Siri and the Live Activity would lose the trip.
- **Keep the map mounted behind the On the Go screen:** CarPlay would keep working, but the phone would still draw a second MapKit map that nobody sees, which costs battery for nothing.
- **Move the view model out of the view:** CarPlay could then run with the phone app in the background. This is a larger change, and 0023 already left it for later.

## Consequences

- The phone draws no map while CarPlay is connected, so one map is drawn instead of two.
- The map's camera mode is still shared with CarPlay (0023), but the phone no longer shows it.
- Whether the screen changes when CarPlay really connects can only be tested on a device with CarPlay and the navigation entitlement. Unit tests and the debug screen cover the rest.
- `TripMapView` belongs to the owner of Trip Started (see [Who owns which screen](../../AGENTS.md#who-owns-which-screen)); the owner agrees before the change is merged.
