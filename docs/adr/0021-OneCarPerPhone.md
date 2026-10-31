# 0021. One car per phone, not per iCloud account

- Status: Proposed
- Date: 2026-10-31
- Deciders: R, F, O, N

## Context

The app statement says one car is one person with one phone. Today a participant is matched by iCloud account: `JoinTrip` returns the existing participant when the same `userRecordID` joins again, so a person can reopen the app and keep their car (US-02, US-03).

In the first user test, two phones signed in to the same Apple ID both showed "Member 1d9d". Phones on one account can turn into one car, and then two GPS readings take turns writing one record, so the car jumps between two places. Families and testers often share an Apple ID, and the team tests on its own phones.

A phone can keep its own random ID in the Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), which survives app restarts and is never synced to other devices.

## Decision

We will match a participant by iCloud account **and** a device ID kept in this phone's Keychain. Joining again from the same phone returns the same car; another phone on the same account joins as a new car. The participant record gains a `deviceID` field, and the trip query matches on both fields.

## Alternatives considered

- **Keep matching by iCloud account only:** no work, but two phones on one Apple ID share one car. Every test then needs a second Apple ID, and real groups that share an account break.
- **Match by device ID only:** simpler, but a person who reinstalls the app gets a second car and cannot get back their old one.
- **Use `identifierForVendor`:** no Keychain code, but it changes when every app from this vendor is deleted, and it is not meant to identify a person.

## Consequences

- Two phones on one Apple ID are two cars, so the team can test with any phones.
- `Participant`, `TripRecordMapper`, `LiveTripService.JoinTrip`, `InMemoryTripService`, `CloudKit/Schema.ckdb`, `CloudKit/TripSync.md` and `specs/UserStories.md` change, so every screen owner reviews it ([AGENTS.md → Who owns which screen](../../AGENTS.md#who-owns-which-screen)).
- The device ID is stored in the Keychain, never in `UserDefaults` ([AGENTS.md → Security](../../AGENTS.md#security)).
- Until this is accepted and built, test with one Apple ID per phone.
