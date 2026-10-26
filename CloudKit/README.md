# CloudKit schema

`Schema.ckdb` is the schema of the trip database in the CloudKit **public** database (ADR 0014). Change the schema here first, in a pull request, then import it into your container. Never change it only in the CloudKit Console.

| Record type | Fields | Indexes |
| --- | --- | --- |
| `Trip` | `roomCode`, `status`, `leaderParticipantID`, `currentWaypointIndex`, `routeVersion`, `createdAt`, `startedAt`, `endedAt` | `roomCode`, `status` queryable |
| `Waypoint` | `tripID` (reference), `orderIndex`, `kind`, `name`, `latitude`, `longitude` | `tripID` queryable, `orderIndex` sortable |
| `Participant` | `tripID` (reference), `userRecordID`, `displayName`, `carDescription`, `latitude`, `longitude`, `speedKmh`, `motionState`, `alert`, `lastSeenAt` | `tripID`, `userRecordID` queryable |
| `Route` | `tripID` (reference), `version`, `polyline` (bytes) | `tripID` queryable, `version` sortable |

Every record type also has queryable `recordName` (needed for subscriptions) and queryable, sortable `modificationDate` (needed to fetch only what changed each second).

The field names match `Lezgo/Services/TripRecordMapper.swift` and `specs/UserStories.md` → "Data model".

**Access:** everyone can read. Anyone signed in to iCloud can create and write. The leader must delete other members' records, and a new leader must update a trip someone else created, so "creator only" writes would not work. The app checks leader-only actions itself (ADR 0014).

## Import the schema into your container

1. Create a CloudKit management token: [CloudKit Console](https://icloud.developer.apple.com) → your container → account menu (top right) → **Manage Tokens** → **Create Token**. Copy it.
2. Save it once on your Mac:
   ```bash
   xcrun cktool save-token --type management
   ```
3. Check, then import, into the **development** environment. Use your own team ID and container (ADR 0015); the release values are shown:
   ```bash
   xcrun cktool validate-schema --team-id K64G2J8QL7 --container-id iCloud.com.nathansudiara.Lezgo --environment development --file CloudKit/Schema.ckdb
   ```
   ```bash
   xcrun cktool import-schema --team-id K64G2J8QL7 --container-id iCloud.com.nathansudiara.Lezgo --environment development --file CloudKit/Schema.ckdb
   ```
4. In the CloudKit Console, check that the four record types, their indexes and their security roles are there.

## Before the first TestFlight build

TestFlight and App Store builds use the **production** environment. In the CloudKit Console, open the release container and choose **Deploy Schema Changes…** to copy the development schema to production. Without this, every save from a TestFlight build fails.

## After changing the schema in the Console

If you had to change something in the Console, export it back and commit it:

```bash
xcrun cktool export-schema --team-id K64G2J8QL7 --container-id iCloud.com.nathansudiara.Lezgo --environment development --output-file CloudKit/Schema.ckdb
```
