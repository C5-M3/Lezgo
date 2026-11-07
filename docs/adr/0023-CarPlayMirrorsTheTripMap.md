# 0023. CarPlay mirrors the trip map with Apple's templates

- Status: Proposed
- Date: 2026-11-07
- Deciders: N

## Context

Apple granted Lezgo the CarPlay navigation entitlement (`com.apple.developer.carplay-maps`), so the trip can be shown on the car's screen (#257).
The Hi-Fi Final page in Sketch has CarPlay frames that copy the phone's Trip Started screen: the map with the yellow route and robot cars, plus our own dark cards for the next turn, the time left, alerts, a tapped car and the arrival.

The [CarPlay Developer Guide](https://developer.apple.com/download/files/CarPlay-Developer-Guide.pdf) (2026-10-13) sets rules for navigation apps:

- The base view must be used only to draw a map. No windows, alerts, panels, overlays or other UI may be drawn in it, and it gets no taps.
- Everything else must use Apple's templates: the map template's navigation bar and map buttons, the guidance and trip estimate panels, navigation alerts, and (from iOS 27) general purpose map panels.
- A navigation app must give turn-by-turn directions and stop guidance at once when CarPlay cancels it.
- Templates may be at most 5 deep, and a map panel holds at most 12 items.

CarPlay runs in its own scene. The phone's trip map already owns the trip: it follows the trip service, shares this phone's GPS, works out alerts and guidance, and moves checkpoints for the leader.

## Decision

We will build CarPlay as a navigation app that mirrors the trip map open on the iPhone, and show everything that is not the map with Apple's templates:

| Sketch card | CarPlay |
| --- | --- |
| Turn card | Guidance panel (`CPNavigationSession` maneuver) |
| "50 min · To Tunjungan Plaza" | Trip estimates on the guidance panel |
| "Off route", "Citra has stopped" | Navigation alert (`CPNavigationAlert`) |
| Car card | Map panel (`CPMapPanel`) opened from a "Cars" button |
| "You have arrived!" | Map panel with the arrival count |
| End Trip / Exit Trip | Navigation bar button, then a `CPAlertTemplate` to confirm |
| Route and location buttons | Map buttons: whole route, follow my car |

The base view draws the same SwiftUI map layer as the phone (route, stops, robot cars) and nothing else.

`TripMapView` registers its view model in a shared `ActiveTripMap` while it is on screen. The CarPlay scene reads the trip from there through `CarPlayTripViewModel`, so the phone and the car show one trip, one GPS feed and one set of alerts. With no trip map open, CarPlay shows the map and the message "Start or join a trip on your iPhone".

CarPlay code goes in two places beside the existing layers: the scene delegate in `App/` and the template code in `Views/CarPlay/`, because templates are views for another screen.

## Alternatives considered

- **Draw the Sketch cards on the map:** matches the design exactly, but breaks guideline 2 of the navigation app rules, so App Review would reject it, and the cards could not be tapped anyway.
- **A driving task entitlement:** allows lists and information templates but no map, so the route and cars could not be shown.
- **A second, independent trip map view model for CarPlay:** CarPlay could open the active trip by itself, even with the phone app in the background. But it would share GPS and move checkpoints a second time on the same phone. Left for later, if drivers need it.

## Consequences

- The CarPlay look follows the system (light and dark), not the Sketch cards; only the map keeps the Lezgo style. Designers should design CarPlay with Apple's templates from now on.
- The trip map view model is shared by two scenes, so its camera mode is shared too: "Whole route" on CarPlay also changes the phone's camera.
- CarPlay shows a trip only while the trip map is open on the phone.
- Map panels start in iOS 27. On iOS 26 CarPlay shows the map, guidance, alerts and End Trip, without the Cars list or the arrival panel.
- Xcode 27's CarPlay Simulator (in Device Hub) needs a real iPhone on a USB cable; the iOS simulator alone cannot show CarPlay.
- Voice prompts are not added: the spec keeps alerts on the road visual only.
- Each developer's provisioning profile must include the CarPlay entitlement, as [Signing on your own account](../../AGENTS.md#signing-on-your-own-account) describes for the other capabilities.
- `Views/CarPlay/` extends the layout of [Architecture: MVVM, layer first](../../AGENTS.md#architecture-mvvm-layer-first).
