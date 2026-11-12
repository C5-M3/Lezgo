# 0029. Ask for "Always" location when the trip starts

- Status: Proposed
- Date: 2026-11-12
- Deciders: N

## Context

Every phone shares its position every second while the trip is open, also with the screen locked or another app in front.
The spec ("Sync and timing" in [`specs/UserStories.md`](../../specs/UserStories.md)) and [ADR 0014](0014-CloudKitPublicDatabaseForTripSync.md) already call for "Always" location permission, asked with a clear reason.
The app only asks for "While Using the App" today: `LiveLocationProvider` opens a `CLServiceSession(authorization: .whenInUse)`.

With "While Using the App", updates stop about 10 seconds after the app leaves the screen, unless the app keeps a `CLBackgroundActivitySession`.
While that session is open, iOS shows a location arrow in the Dynamic Island, beside the trip's own Live Activity ([ADR 0028](0028-LiveActivityInAWidgetExtension.md)).
One app then shows two items there, and a session left behind by a killed app kept the arrow on until the phone restarted (#316).
Apple Maps shows no arrow because it is a system app; third-party apps cannot hide it.

With "Always", no background session is needed, so the arrow does not show.
With PR #318 (for #316) the app makes no background session when the person has already given "Always" in Settings.
This was checked on a phone: the arrow was gone and the car kept moving on another phone's map with the screen locked.

How iOS asks for "Always":

- From "While Using the App", the app can ask once. iOS shows "Change to Always Allow?" at once. If the person says no, the app can never ask again; only Settings can change it.
- From "not determined", iOS first asks for "While Using the App" and offers "Always" later, at a moment the system picks.
- The `NSLocationAlwaysAndWhenInUseUsageDescription` text is already in the build settings.

App Review accepts "Always" when the reason is clear and the feature needs it. Many people turn it down, so the app must keep working without it.

## Decision

We will ask for "Always" once, when the trip map opens for a trip on the road (leader and members), by opening a `CLServiceSession(authorization: .always)` there.
Without "Always", the trip map keeps working as today, with the background session and its arrow.

## Alternatives considered

- **Keep "While Using the App" only:** simplest, and Apple's engineers advise leaving the arrow alone. But every driver sees the arrow beside the Live Activity, and it goes against the spec and ADR 0014.
- **Ask on Home or in the Trip Room:** the person does not yet see why the app needs location with the screen locked, so more people say no, and the one chance is lost. AGENTS.md also asks for permissions at the moment they are needed.
- **Our own screen before the system prompt:** explains the reason first and can save the one chance. It adds a screen to a moment when the driver is starting to drive; it can be added later if too many people say no.

## Consequences

- The trip map screen (Trip Started) asks for "Always" the first time a trip starts on that phone. Home, Set Route and the Trip Room keep asking only for "While Using the App".
- `LiveLocationProvider` asks for `.always` only when `keepsRunningInBackground` is on; everywhere else it keeps `.whenInUse`.
- A person who says no keeps "While Using the App": sharing goes on with the background session and the arrow. The trip map does not ask again.
- The App Store review notes must say why Lezgo needs "Always": sharing the car's position with the group while the screen is off, only during an open trip.
- Location still stops when the trip closes, and closing the app stops it ([Security](../../AGENTS.md#security): fewest permissions, at the moment they are needed).
- The "Always" path needs a check on a real phone in every release, because the simulator shows neither the prompt's timing nor the arrow.
