# 0031. Minimum iOS 18, with newer features behind availability checks

- Status: Proposed
- Date: 2026-11-13
- Deciders: Oky Faishal (proposed), the team (to approve)

## Context

[0002](0002-SwiftUIAndSwiftDataOnIOS27.md) chose the newest iOS because Lezgo had no users on older versions. The deployment target is iOS 26.0: it is set once for the project, which the app and `LezgoWidgets` inherit, and again in `LezgoTests` and `LezgoUITests`. [0027](0027-ChooseOnMapWithNativeMapKit.md) relies on it: "every MapKit API for SwiftUI is available".

A group trip only works when every car in the group can install the app. A driver whose phone runs iOS 18 to iOS 25 cannot install Lezgo today, so the whole group cannot use it. The team wants iOS 18.0 as the minimum.

A trial build on `dev` with the target set to 18.0 fails with 37 errors in 17 app files, plus 2 in `LezgoTests/ViewModels/HomeViewModelTest.swift`. Every error reads "is only available in iOS 26.0 or newer".

- **MapKit, 20 errors in 8 files:**
  - Making a map item from a coordinate with `MKMapItem(location:address:)`: `DrivingDirectionsService`, `RoutingService`, `DraftTripView`, `CarPlayTripMapTemplate`, and the test helper.
  - Reading a map item's coordinate with `MKMapItem.location`: `LocationFindService`, `HomeViewModel`, `LivePlaceLookupService` and the test.
  - Reverse geocoding with `MKReverseGeocodingRequest` and `MKMapItem.address`: `LiveStreetNameService` and `LivePlaceLookupService`.
- **App Intents, 13 errors in 8 files** ([0030](0030-SiriWithAppIntents.md)):
  - `supportedModes` (`IntentModes`) is set in every intent: `.background` in six of them, and `[.background, .foreground(.dynamic)]` in `JoinTripIntent` and `CreateTripIntent`.
  - Both of those intents call `systemContext.currentMode` and `continueInForeground(_:alwaysConfirm:)` through `JoinTripIntent.OpenApp`.
  - `MuteAlertsIntent` returns an interactive `SnippetIntent` card.
- **Liquid Glass, 4 errors in 1 file:** `glassEffect`, `.buttonStyle(.glass)` and `GlassEffectContainer` in `TravelSearchBar`, which nothing uses. Its `#available(iOS 18.0, *)` check is wrong; Liquid Glass starts in iOS 26.

What else the trial builds showed:

- With the availability check turned off, all four targets build for iOS 18. No other kind of error is hidden behind these 39.
- The compiler gives the same 22 warnings as the iOS 26 build.
- The App Intents metadata is extracted for an iOS 18.0 target.
- `LezgoUITests` type-checks for iOS 18 without errors.
- A build for iOS 17 fails only on `supplementalActivityFamilies` and `activityFamily` in the widget. Every other API the app uses below iOS 26 is in iOS 18.

What Apple's documentation and our checks say about each fallback:

- **MapKit:** `MKPlacemark`, `MKMapItem(placemark:)` and `CLGeocoder` work on iOS 18 and are deprecated from iOS 26. Apple's guide to geocoding says a geocoder object handles one conversion only, and that Apple limits how often an app may convert.
- **Intent modes:**
  - An intent that does not set `supportedModes` gets the same value in the metadata as one that sets `.background`. `MuteSnippetIntent`, which sets nothing, is stored as `1`, exactly like the six `.background` intents.
  - A `static let supportedModes` marked `@available(iOS 26.0, *)` builds for iOS 18 and is still stored as `[.background, .foreground(.dynamic)]` (`9`).
  - `openAppWhenRun` is deprecated in favour of `supportedModes`.
- **Siri card:** Apple calls a snippet that runs an intent from a button an interactive snippet. Interactive snippets are made with `SnippetIntent`, which is iOS 26 only. Before iOS 26 an intent can show only a static `ShowsSnippetView` card.
- **Siri phrases:** `AppShortcutsProvider` does not allow `if #available` in its builder ("closure containing control flow statement cannot be used with result builder 'AppShortcutsBuilder'"). One Siri phrase cannot point to a different intent on each iOS version.
- **Look of the app:** an app linked against the newest SDK uses the design of the OS it runs on, unless `UIDesignRequiresCompatibility` is set. Lezgo does not set it, so lowering the deployment target does not take Liquid Glass away from iOS 26 users.
- **Tests:** Swift Testing reports a test marked `@available(iOS 26.0, *)` as skipped on an older iOS.

## Decision

We will set the minimum iOS version to 18.0 and keep every feature that needs a newer iOS. Each one is switched on at run time with `if #available` or `@available` on phones that have that version, and has a working fallback on older ones.

- **Map items:** making a map item from a coordinate and reading its coordinate go through a small extension on `MKMapItem` in `Extensions/`. It uses `MKMapItem(location:address:)` and `location` on iOS 26, and `MKPlacemark` before that. Views, view models and services call the extension, not `#available`.
- **Reverse geocoding:** the version check stays inside `LiveStreetNameService` and `LivePlaceLookupService`, which already sit behind the `StreetNameService` and `PlaceLookupService` protocols. Before iOS 26 they use a new `CLGeocoder` for each request. They turn its `CLPlacemark` into the same "Street, Area, City" text that `MKAddress.shortAddress` gives. The existing `StreetName(shortAddress:name:)` and `MakeAddress(shortAddress:name:)` functions and their tests then work for both versions. The callers keep deciding how often to ask, as they do now.
- **Intent modes:** the six `.background` intents stop setting `supportedModes`, because the default is the same. `JoinTripIntent` and `CreateTripIntent` keep it as a `static let` marked `@available(iOS 26.0, *)`.
- **Opening the app from Siri:** before iOS 26, `JoinTripIntent.OpenApp` returns without opening Lezgo. "Join a trip" and "Create a trip" do their work in the background, and Home opens the trip the next time Lezgo opens. This is the path these intents already take on a locked phone or in CarPlay. We do not set `openAppWhenRun`: it is deprecated, and opening Lezgo before the work cut Siri off on a real phone, and nothing was joined.
- **Liquid Glass:** we use it only inside `if #available(iOS 26.0, *)`, with a material on older versions. System controls follow the running OS on their own.
- **Tests:** a test of an iOS 26 path is marked `@available(iOS 26.0, *)`. A test of a fallback path calls the fallback directly, so it runs on every version.
- **iOS 27 features:** the CarPlay map panels ([0023](0023-CarPlayMirrorsTheTripMap.md)) keep their checks.

When this record is accepted, 0002's status becomes `Superseded by 0031`, and 0027's line about the deployment target no longer holds.

## Alternatives considered

- **Stay on iOS 26:** no extra code, but drivers on iOS 18 to iOS 25 cannot join their group's trip, which defeats the app's purpose.
- **iOS 18, and drop the iOS 26 features for everyone:** one code path, but iOS 26 users would lose Siri opening the Trip Room and the interactive Mute card for no reason.
- **iOS 17:** the build for iOS 17 adds only the widget's small family for Apple Watch and CarPlay, but the team asked for iOS 18. Each older version adds fallbacks to write and test.
- **One MapKit helper in `Services/` for everything:** reverse geocoding already sits behind service protocols, and making or reading a map item is a small extension on an Apple type. A third type would duplicate both.
- **Availability checks at every call site:** no helper to write, but the same `#available` would repeat in 8 files and drift apart.
- **`supportedModes` as a computed `static var`:** this also builds, but the stored `static let` is the form whose value we checked in the App Intents metadata.
- **`openAppWhenRun = true` before iOS 26:** it is deprecated, and it brings Lezgo to the front before the join is done, which already failed on a real phone.

## Consequences

- Phones on iOS 18 to iOS 25 can install Lezgo. Route planning, the Trip Room, the trip map, alerts, CarPlay, CloudKit sync and the Live Activity on the Lock Screen and in the Dynamic Island work there as on iOS 26.
- Before iOS 26, these features are reduced:
  - Siri "Join a trip" and "Create a trip" do not open Lezgo; the Trip Room appears when the user opens the app.
  - Siri "Mute Lezgo" still mutes and unmutes, but its card cannot have a button to flip it back. Siri phrases cannot change per version, so `MuteAlertsIntent` has two options. It can show a static card on every version, which also takes the button away from iOS 26 users. Or it can keep a second, iOS 26-only intent for the interactive card, which no phrase can reach. The team decides in the implementation pull request.
  - The system controls use the look from before Liquid Glass, and the CarPlay dashboard shows no Live Activity.
  - Addresses come from `CLGeocoder`. Its street and area names can differ from `MKAddress` for the same place, so Set Route, Choose on Map and the car card's street must be checked on both versions.
- New code that uses an API newer than iOS 18 needs an availability check and a fallback. The compiler enforces the check; review enforces the fallback.
- Tests run on an iOS 18 simulator as well as an iOS 27 one, so every developer installs an iOS 18 runtime.
  - The test command in AGENTS.md and the simulator note in `README.md` change to match.
  - The Xcode Cloud workflow, which is set up outside this repository, gains an iOS 18 test destination.
- The change touches shared code and other owners' screens: Services, Intents and CarPlay (Nathan), Draft Trip and Home (R). They review it before it is merged.
- AGENTS.md "Project snapshot" changes to iOS 18.0+, and AGENTS.md "Swift and SwiftUI rules" gains the availability rule above.
