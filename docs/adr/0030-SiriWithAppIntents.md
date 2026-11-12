# 0030. Siri questions about the trip with App Intents

- Status: Proposed
- Date: 2026-11-12
- Deciders: N (Vallykrie), to be agreed by R, F and O

## Context

On the road the driver must not look at the phone ("Safety first" in AGENTS.md). Today the only way to know where
the leader is, whether the group is together or how long is left is to look at the trip map or tap a car. Voice
guidance (ADR 0024) speaks turns and alerts, but the driver cannot ask anything.

Siri can run an app's actions by voice, with "Hey Siri", the side button, AirPods and CarPlay. Apple's App Intents
framework is how an app offers these actions. App Shortcuts (`AppShortcutsProvider`) give them spoken phrases that
work as soon as the app is installed, with no setup, and also appear in the Shortcuts app and Spotlight.

Constraints:

- The trip map already runs in the background with the screen locked (location background mode), and
  `ActiveTripMap.shared` holds its view model so CarPlay can read it (ADR 0023).
- On CarPlay, Siri answers by voice only: no snippet card is shown.
- The app is English only, and copy comes from `specs/UserStories.md` word for word (ADR 0016).
- No third-party dependencies. App Intents is an Apple framework.
- Destructive actions ask for confirmation on screen (ADR 0025). A misheard voice command must not end a trip.

## Decision

We will add Siri phrases with App Intents and App Shortcuts that answer questions about the trip on the road and
run two safe actions (mute and "I've Arrived"), as specified in US-08.

- **Intents:** where the leader is, where a named car is, whether everyone is with the group, how long is left,
  mute or unmute, and "I've Arrived". Each is an `AppIntent` with `supportedModes = .background`, so it answers
  without opening the app, and returns a spoken `IntentDialog`; on the phone it also shows a small snippet view.
- **No destructive intents:** End Trip, Exit Trip, removing a participant and handing over the lead stay on the
  screen with the shared confirmation. Joining and planning a trip need typing, so they stay in the app too.
- **Where the answers come from:** the intents read the open trip map through `ActiveTripMap.shared`, the same
  object CarPlay reads. With no trip map open (no trip, Trip Room, or the app was closed), every intent answers
  "No trip is on the road. Open Lezgo to start or join one."
- **Thin intents, tested answers:** a plain `TripAnswers` type builds every sentence from a `TripState`, this phone's
  participant ID, its location and its guidance. It is unit tested with Swift Testing like any service. The intents
  only find the trip map, call `TripAnswers` and return the result.
- **Cars by name:** a `TripCarEntity` (`AppEntity`) lists the cars of the open trip, so "Where's Budi in Lezgo"
  works. The trip map calls `LezgoShortcuts.updateAppShortcutParameters()` when the list of cars changes.
- **Actions reuse the trip map:** mute uses the same switch as the map's Mute button (ADR 0024), and "I've Arrived"
  calls the same code as the button, with the same 1 km rule, after `requestConfirmation`.
- **Folder:** intents, the entity and the shortcuts provider go in a new layer folder, `Lezgo/Intents/`. They are
  not views, view models or services, and Apple groups them the same way in its samples. The SwiftUI cards Siri
  shows go in `Views/Siri/`, next to `Views/CarPlay/`.
- **Cards:** the questions return a static snippet (`ShowsSnippetView`). The mute card uses a `SnippetIntent`, so
  its Mute / Unmute button works inside Siri (iOS 26 and later). The car card's map is a still picture
  (`MKMapSnapshotter`), because a live map cannot run inside Siri.

## Alternatives considered

- **SiriKit (`INExtension`, Intents framework):** the older API. Apple's navigation intents do not cover group
  questions, it needs an extension target, and Apple now points new work to App Intents.
- **Opening the app for every intent (`.foreground`):** simpler, but the screen lights up and the driver looks at
  it, which is what this feature is meant to avoid.
- **A custom voice command inside the app (Speech framework):** needs the app open, a microphone prompt and our own
  wake word. Siri already does this, on CarPlay too.
- **Intents in `Services/`:** they are system entry points, closer to views than to services, and would hide
  `TripAnswers` among them.

## Consequences

- Drivers can ask about the group without looking at the phone, on the phone and on CarPlay.
- AGENTS.md gains `Intents/` in the folder tree. Intent types are named `<Action>Intent` (`WhereIsLeaderIntent`),
  like views end in `View`.
- `TripAnswers` and its copy are covered by unit tests; the intents themselves are checked by hand with Siri and the
  Shortcuts app, and optionally by an App Intents Testing UI test.
- Siri only answers while the trip map is open on the phone, including in the background. If the app was closed,
  the driver has to open it first. Restoring the trip in the background for Siri can come later.
- Phrases are English only, like the rest of the app. Adding Indonesian later means translating the phrases in the
  String Catalog (`AppShortcuts.xcstrings`).
