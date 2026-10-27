# 0014. CloudKit public database for trip sync

- Status: Proposed
- Date: 2026-10-23
- Deciders: Nathan Sudiara

## Context

Every car in a trip runs its own phone, and the phones must share one trip: the route, the participant list, the trip status and each car's position. "Sync and timing" in `specs/UserStories.md` sets the targets: each phone sends its location every 1 second, other phones see a new position or status change within 2 seconds, and Start Trip reaches every phone within 1 second.
The cars can be far apart on a highway, so the phones cannot rely on being near each other. The team has six days, no server engineer and no budget for hosting, and AGENTS.md asks for no third-party dependencies without approval.

## Decision

We will sync trips through the CloudKit public database of container `iCloud.com.nathansudiara.Lezgo`, with record types `Trip`, `Waypoint`, `Participant` and `Route`.

- **Identity:** the user's iCloud account. There is no sign-up screen and no password to store.
- **Writes:** each phone saves only its own `Participant` record (position, status, `lastSeenAt`) once per second while the trip is open. Route and trip changes save the `Trip`, `Waypoint` and `Route` records.
- **Reads:** each phone fetches the trip every 1 second, at a fixed rate, while the app is open: the `Trip` record and the members it already knows, by record ID, in two requests sent together. A query for members who just joined runs every 2 seconds, and waypoints and route are fetched again only when `routeVersion` changes. A CloudKit query subscription can be added for when the app is in the background; silent pushes alone are not enough, because iOS delays and drops them.
- **Writes of a position:** one request that saves only the location fields (`.changedKeys`), without fetching the record first. All requests are sent as user-initiated, so iOS does not hold them back.
- **Code:** all CloudKit calls live behind the `TripService` protocol (`LiveTripService`, `MockTripService`), so view models and tests never touch CloudKit.

## Alternatives considered

- **Own backend (for example Vapor with WebSockets):** the lowest latency and full control, but it needs a server to build, host, secure and pay for, plus our own accounts. Too much for six days and a team without a server engineer.
- **Firebase (Firestore or Realtime Database):** real-time listeners out of the box, but it is a third-party SDK with its own accounts, sends location data to Google, and adds App Store privacy answers for a third party. AGENTS.md asks us to avoid such dependencies.
- **Multipeer Connectivity:** no server at all, but its range is a few tens of metres over Wi-Fi or Bluetooth. Cars on a road trip are often hundreds of metres or kilometres apart, so it fails the core use case.

## Consequences

- No server to run or pay for, and no new dependency. Every person in a trip needs to be signed in to iCloud; the app must explain this clearly when they are not (`TripServiceError` "not signed in to iCloud").
- The public database has request limits that grow with the number of active users. One write per second per car is near the edge of what CloudKit is meant for, so task 0.8 (sync load check, #69) measured real latency and throttling before the convoy test. If a later test fails the 2-second target, a new ADR supersedes this one.
- **Load check result (#69, 26 Oct 2026):** one car on an iPhone 16e for 30 minutes, development environment. 5,340 requests (2.97 per second) with no throttling and no errors. Request time p50 481 ms, p95 1.0 s. A saved position was seen again after p50 0.96 s, p95 1.48 s, max 2.33 s, and 99% of positions within 2 seconds. The battery stayed at 96%, so less than about 1% in 30 minutes with the screen on.
- Two findings shaped the read and write design above. Querying the members every second took about 2.8 s from save to seen (26% within 2 s); reading known members by record ID brought it under 1 s. Several simulated cars on one phone queue up in that phone's CloudKit client at about 6 to 7 requests per second, so load is measured with one car per phone.
- Record types, indexes and security roles live in the CloudKit Dashboard. The schema is exported with `xcrun cktool export-schema` to `CloudKit/Schema.ckdb` at the repository root (task 0.10) so changes are reviewed in pull requests. It stays outside `Lezgo/`, because files in that synchronized folder are copied into the app bundle. It must be deployed to production before the first TestFlight build, because TestFlight and App Store builds use the production environment.
- **Security roles:** any user can read, and any user signed in to iCloud can create and write all four record types. The leader must remove other members' `Participant` records, and after a hand-over the new leader must update a `Trip` they did not create, so "creator only" write access does not work. The app checks leader-only actions itself. The risk is small: record names are random UUIDs that a phone only learns by joining with the room code.
- The app needs the iCloud (CloudKit) capability, the location-updates and remote-notifications background modes, and "Always" location permission (task 0.2). See [Architecture: MVVM, layer first](../../AGENTS.md#architecture-mvvm-layer-first) for the service-behind-a-protocol rule.
