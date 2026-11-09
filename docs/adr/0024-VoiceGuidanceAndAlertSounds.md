# 0024. Voice guidance and alert sounds on the trip map

- Status: Proposed
- Date: 2026-11-09
- Deciders: N (Vallykrie), to be agreed by R, F and O

## Context

The spec says "Alerts on the road are visual only. No sound, no vibration." and lists sound notifications as out of
scope (`specs/UserStories.md`, "Sync and timing" and "Not in scope"). Every banner on the trip map and every
CarPlay navigation alert is silent.

On the road this means the driver has to look at the phone to know the next turn or that they left the group. Apple
Maps and Google Maps speak the next turn for exactly this reason: a driver who hears it keeps their eyes on the road.
The app's safety rule ("the driver must not be distracted") is better served by sound than by silence.

Constraints:

- One person per car, usually driving, often with music or a podcast playing, sometimes on CarPlay.
- The trip map already runs in the background with the screen locked (location background mode).
- MapKit already gives a localized instruction for each turn (`TripMapGuidance.instruction`).
- No third-party dependencies.

## Decision

We will speak the next turn and play a short sound for every new alert on the trip map, with one mute button that
turns both off.

- **Voice guidance:** the turn card's instruction is spoken with `AVSpeechSynthesizer` in the phone's language: once
  at about 500 m (only when the turn was further than that), once at about 200 m, and once at the turn (30 m). Each
  turn is spoken at most once per distance. A new route or changed stops are spoken too ("New route", "Route updated").
- **Alert sound:** when a formation alert, a "[name] has stopped" banner or an urgent notice (reroute failed, leader
  offline) appears, a short chime plays and the banner text is spoken once. The same banner staying on screen does
  not repeat it. The car pins themselves stay silent.
- **Audio session:** `.playback` with mode `.voicePrompt` and `.duckOthers` + `.interruptSpokenAudioAndMixWithOthers`,
  active only while speaking, then deactivated with `.notifyOthersOnDeactivation` so music comes back. It plays
  through CarPlay's speakers when connected. We add `audio` to `UIBackgroundModes` so guidance is heard with the
  screen locked, as navigation apps do.
- **Mute:** a button on the trip map ("Mute" / "Unmute", `speaker.slash.fill` / `speaker.wave.2.fill`) turns off both
  voice and chime. The choice is kept in `UserDefaults` (a preference, not a secret) and CarPlay follows it.
- **Code:** a `NavigationSpeaker` protocol with `LiveNavigationSpeaker` (AVFoundation) and a mock for tests. A
  `TripMapAnnouncer` decides what to say from guidance, banner and notice changes, so the rules are unit-tested
  without audio. `TripMapViewModel` owns it; CarPlay reads the same view model, so nothing is spoken twice.
- **Haptics:** still none. A phone in a car mount cannot be felt.

## Alternatives considered

- **Keep the trip map silent (current spec):** the driver has to look at the screen for every turn and alert, which
  is the distraction the safety rule wants to avoid.
- **Voice guidance only, alerts silent:** the alerts that matter most ("You're out of the way", "Agus is offline")
  would still need a look at the screen.
- **A chime without speech for alerts:** the driver hears that something happened but still has to read what.
- **Sound only while the app is in front:** guidance would stop when the screen locks, which is the common case on
  the road.

## Consequences

- `specs/UserStories.md` changes in the same PR: the "visual only" rule, the CarPlay table, US-06's formation alerts
  and rerouting notice, the Gherkin scenarios that say "no sound plays", and "sound notifications" leaves "Not in
  scope".
- `Info.plist` gains the `audio` background mode. App Review accepts it for spoken navigation guidance.
- `TripMapViewModel` takes a `NavigationSpeaker` through its initializer; previews and tests pass a silent mock.
- The team must check that new banners added later get a spoken text, or say why they stay silent.
- The rule lives in AGENTS.md → "Project context" ("Alerts are visual, controls are large"), which becomes "Alerts
  are visual and spoken, with a mute button".
