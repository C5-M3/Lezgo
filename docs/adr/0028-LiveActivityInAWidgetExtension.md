# 0028. Live Activity for the trip in a widget extension

- Status: Proposed
- Date: 2026-11-12
- Deciders: N

## Context

During user tests, drivers locked the phone or switched to music or messages, and lost sight of the trip until they opened Lezgo again.
iOS shows ongoing tasks on the Lock Screen, in the Dynamic Island and, from iOS 26, on the CarPlay dashboard as a Live Activity.

A Live Activity is drawn by a widget extension: a second target with its own bundle identifier, signed by the same team.
The app starts, updates and ends the activity with ActivityKit. Updates can come from the app itself or from Apple's push service; push updates need a server that holds the activity's push token, and CloudKit cannot send them.

The trip map already runs in the background during a trip (location and audio background modes), so the app is awake every second while a trip is open. `ActiveTripMap` already lets a second screen (CarPlay, [ADR 0023](0023-CarPlayMirrorsTheTripMap.md)) read the trip map that is open on the phone.

The spec keeps alerts on the road visual and spoken, with no vibration ([ADR 0024](0024-VoiceGuidanceAndAlertSounds.md)).

## Decision

We will add a widget extension target, `LezgoWidgets`, that draws one Live Activity for the open trip.
The app updates it locally from the trip map that `ActiveTripMap` holds, with no push server.
Only the attributes and content state are shared between the app and the extension; the extension holds views only.

## Alternatives considered

- **Push updates through a server:** keeps the activity fresh even if iOS suspends the app, but needs our own server and APNs keys. The app is already awake during a trip, so local updates are enough.
- **ActivityKit alert configuration for formation alerts:** lights the screen and expands the Dynamic Island, but plays a system sound and vibrates, which breaks ADR 0024 and doubles the spoken alert. The alert is shown in the content state instead.
- **A Home Screen widget as well:** no use while driving; left out.

## Consequences

- A new target and folder, `LezgoWidgets/`, beside `Lezgo/`. Its bundle identifier is `$(BUNDLE_IDENTIFIER_PREFIX).Lezgo.Widgets`, so per-developer signing ([ADR 0015](0015-PerDeveloperSigningSettings.md)) keeps working with no new setting.
- The app's Info.plist gets `NSSupportsLiveActivities`. No new entitlement is needed.
- Xcode Cloud must sign and embed the extension; the first TestFlight build after this change needs checking.
- The Live Activity shows a trip only while the trip map is open on the phone, the same rule as CarPlay.
- The extension adds a folder to [Architecture: MVVM, layer first](../../AGENTS.md#architecture-mvvm-layer-first).
