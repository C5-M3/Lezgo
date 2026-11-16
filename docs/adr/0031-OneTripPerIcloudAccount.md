# 0031. One trip per iCloud account, checked in CloudKit

- Status: Proposed
- Date: 2026-11-16
- Deciders: R, F, O, N

## Context

The same iCloud account can be signed in on two or more phones. Today the app does not handle this:

- Whether the app opens on Home or on Draft Trip depends on `UserDefaultsActiveTripStorage`, which lives on one phone only. A second phone on the same account always opens on Home, even when the account already has a trip.
- `CreateTrip` does not look for other trips of the account, so one account can lead several trips.
- `JoinTrip` only looks for an existing participant inside the trip being joined (`tripID` and `userRecordID`). Two phones joining the same trip become one car and write two GPS readings into one record. Joining a different trip is accepted, and the first phone is never told.
- `ActiveTripSummary` does not record which iCloud account it belongs to, so after an account switch the phone can show another account's trip.

[0021](0021-OneCarPerPhone.md) (Proposed) wants the opposite: two phones on one account become two cars. The first user test and the product rule changed that view: one iCloud account is one person, and a person is in one trip at a time.

Constraints:

- **The CloudKit schema does not change.** `CloudKit/Schema.ckdb` keeps its five record types (`Trip`, `Waypoint`, `Participant`, `Trail`, `Route`) and their fields.
- The public database has no transactions and no unique constraints. A "check, then write" rule lets two phones that act at the same moment both pass the check.
- A `Participant` record name must be a UUID (`TripRecordMapper.MakeParticipant`), so a fixed per-account name cannot be used for `Participant`.
- A `Trail` record is already named by a fixed rule (`"{tripID}-trail"`) and is only ever read with `Fetch` by ID, never by query (`TripRecordReader.Trail`).

## Decision

We will treat one iCloud account as one person who is in at most one open trip (`LOBBY` or `IN_TRIP`), and keep that fact in one **seat** record per account in CloudKit.

**The seat record**

- It is a `Trail` record with a fixed name made from the account: `"{hash of the iCloud user record name}-seat"`. Use CryptoKit (SHA-256), so the account ID is not stored in the clear.
- `polyline` holds a small payload of three UUIDs (48 bytes): the `tripID` the account is in, its `participantID`, and a `sessionID` (a random UUID made each time a phone joins). The record has no `tripID` reference field: a seat is claimed before the trip record exists, and a reference to a missing record could fail. No new field and no new record type.
- The seat is read and written only by `Fetch` and `Save` by ID, never by query, so the trip readers never see it.

**Rules**

- **On every app open,** `Fetch` the seat. No seat, or a stale seat: show Home. A live seat: show Draft Trip. The local summary only gives a fast first screen and is replaced by the CloudKit answer. A summary saved for another iCloud account is dropped (it now stores the user record name hash).
- **A seat is stale** when its trip is not open (`ENDED`, `CANCELLED` or missing) or its participant no longer exists. A stale seat counts as no seat, and is overwritten by the next claim. Nothing has to clean the seat when a leader removes a member or a trip ends.
- **`CreateTrip` and `JoinTrip` claim the seat with a conditional save** (`.ifServerRecordUnchanged`, the way `SetLeader` already saves). If another phone claimed it first, the save fails, the loser reads the seat and, when it is live for another trip, throws the new `TripServiceError.alreadyInTrip`. This is atomic, so two phones acting at the same moment cannot both win.
- **The newest phone wins.** Joining the trip the account is already in replaces the seat's `sessionID` with a conditional save and returns the same participant. A phone that reads a different `sessionID` stops sending its location, clears its local summary, shows an alert ("You joined this trip on another device") and returns to Draft Trip.
- **Draft Trip is not a re-join.** Continuing from Draft Trip on the older phone is a new join and takes the seat back. A confirmation says that it disconnects the other device, so the two phones do not flip the seat by accident.
- **A phone in a trip reads its seat every few seconds** with a plain `Fetch` by ID, separate from the trip poll. That adds about one request per phone every 3 seconds to the load that #69 and #220 keep within CloudKit's limits.
- **`CreateTrip` claims the seat before it saves the trip**, with the IDs it has made. A claim that is followed by a failed save leaves a stale seat (its trip is missing), which heals itself. A seat for an older trip that has no seat yet (a trip made before this change) is claimed when its member joins again.

## Alternatives considered

- **A new `Membership` record type, or a `sessionID` field on `Participant`:** the cleanest design, but it changes the schema, which this decision is not allowed to do.
- **Only `Participant`, with a random ID per phone and a recheck after writing:** takeover means a new participant and a deleted one, and the old phone finds itself missing. It needs no seat, but the check is not atomic. A "write, query again, the older one wins" step shrinks the race and depends on a query that sees the newest write, which we could not confirm. Taking over as leader also needs a conditional change of `Trip.leaderParticipantID` and a copy of the participant's state.
- **One car per phone ([0021](0021-OneCarPerPhone.md)):** it fixes the jumping car, but lets one account be in many cars and does not match the rule that one account is one person. This record would supersede it.
- **Block the second phone ("already in a trip on another device"):** simple, but a lost, broken or forgotten phone would lock the account out. The newest phone wins instead.
- **Keep the check on the phone only:** no CloudKit work, but a second phone cannot know about the trip, which is the problem.
- **CloudKit private database with subscriptions:** per-account state, not readable by others, and pushed to the other phone. It would supersede [0014](0014-CloudKitPublicDatabaseForTripSync.md), needs a push entitlement and is far larger than this problem.

## Consequences

- The seat reuses the `Trail` record type for a second purpose. This is safe only while `Trail` is read by ID. Anyone who adds a query on `Trail` by `tripID` must skip names that end in `-seat`. The seat code carries a comment saying so.
- Home, Draft Trip, Create (Set Route) and Join (Insert Code) change, and so do the shared `TripService`, `TripRecordMapper`, `LiveTripService`, `InMemoryTripService`, `ActiveTripSummary`, `CloudKit/TripSync.md` and `specs/UserStories.md`. `CloudKit/Schema.ckdb` does not change. Every screen owner reviews it ([AGENTS.md → Who owns which screen](../../AGENTS.md#who-owns-which-screen)).
- Opening the app needs a network `Fetch` before the right screen is known. The local summary covers the wait, and a failed `Fetch` keeps the local summary with a retry message, as `continueDraftTrip` does today.
- Until the old phone reads the new `sessionID` (about one poll), it can still write one more location. It stops sending after that. Whether a write from a phone that is no longer in the trip is ignored must be checked in `UpdateLocation` when this is built.
- Nothing closes a trip that is never ended, so its members are locked to it. Draft Trip's "new trip" (`ConfirmNewTrip`) ends it for the leader and exits it for a member, which frees the account. An automatic close of a trip whose cars have all been offline for a set time (from `Participant.lastSeenAt`) is not decided here and needs its own record.
- The rule is enforced by the app only. The public database lets any iCloud user write any record (`GRANT WRITE TO "_icloud"`), so a modified client could ignore it. This is accepted for a team app.
- Tests with several phones need one Apple ID per phone again, unless they test this rule. `InMemoryTripService` and the fake `CloudDatabase` get the same seat rules, so every rule is tested without iCloud.
- 0021 should be marked `Superseded by 0031` when this record is accepted. Until then it stays Proposed and must not be built.
