# 0014. CloudKit public database for trip sync

- Status: Proposed
- Date: 2026-10-23
- Deciders: Nathan Sudiara

## Context

Every car in a trip runs its own phone, and the phones must share one trip: the route, the participant list, the trip status and each car's position. "Sync and timing" in `tasks/UserStories.md` sets the targets: each phone sends its location every 1 second, other phones see a new position or status change within 2 seconds, and Start Trip reaches every phone within 1 second.
The cars can be far apart on a highway, so the phones cannot rely on being near each other. The team has six days, no server engineer and no budget for hosting, and AGENTS.md asks for no third-party dependencies without approval.

## Decision

We will sync trips through the CloudKit public database of container `iCloud.com.nathansudiara.Lezgo`, with record types `Trip`, `Waypoint`, `Participant` and `Route`.

- **Identity:** the user's iCloud account. There is no sign-up screen and no password to store.
- **Writes:** each phone saves only its own `Participant` record (position, status, `lastSeenAt`) once per second while the trip is open. Route and trip changes save the `Trip`, `Waypoint` and `Route` records.
- **Reads:** each phone listens to a CloudKit query subscription for the trip and also fetches the trip's changed records every 1 second while the app is open. Silent pushes alone are not enough, because iOS delays and drops them.
- **Code:** all CloudKit calls live behind the `TripService` protocol (`LiveTripService`, `MockTripService`), so view models and tests never touch CloudKit.

## Alternatives considered

- **Own backend (for example Vapor with WebSockets):** the lowest latency and full control, but it needs a server to build, host, secure and pay for, plus our own accounts. Too much for six days and a team without a server engineer.
- **Firebase (Firestore or Realtime Database):** real-time listeners out of the box, but it is a third-party SDK with its own accounts, sends location data to Google, and adds App Store privacy answers for a third party. AGENTS.md asks us to avoid such dependencies.
- **Multipeer Connectivity:** no server at all, but its range is a few tens of metres over Wi-Fi or Bluetooth. Cars on a road trip are often hundreds of metres or kilometres apart, so it fails the core use case.

## Consequences

- No server to run or pay for, and no new dependency. Every person in a trip needs to be signed in to iCloud; the app must explain this clearly when they are not (`TripServiceError` "not signed in to iCloud").
- The public database has request limits that grow with the number of active users. One write per second per car is near the edge of what CloudKit is meant for, so task 0.8 (sync load check) measures real latency and throttling with a full group before the convoy test. If it fails the 2-second target, a new ADR supersedes this one.
- Record types, indexes and security roles live in the CloudKit Dashboard. The schema is exported to `Lezgo/Resources/CloudKitSchema.ckdb` (task 0.10) so changes are reviewed in pull requests, and it must be deployed to production before release.
- The app needs the iCloud (CloudKit) capability, the location-updates and remote-notifications background modes, and "Always" location permission (task 0.2). See [Architecture: MVVM, layer first](../../AGENTS.md#architecture-mvvm-layer-first) for the service-behind-a-protocol rule.
