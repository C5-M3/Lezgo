import CloudKit
import Foundation
import Testing
@testable import Lezgo

/// Rules only `LiveTripService` has: CloudKit records, errors and polling. The shared rules are in the
/// `TripService*Tests` suites.
struct LiveTripServiceTests {
    let server = FakeCloudServer()

    private func Phone(
        _ userRecordName: String?,
        makeRoomCode: @escaping () -> String = { "897654" }
    ) -> LiveTripService {
        LiveTripService(
            database: FakeCloudDatabase(server: server, userRecordName: userRecordName),
            clock: { TripFixtures.now },
            pollInterval: .milliseconds(5),
            makeRoomCode: makeRoomCode
        )
    }

    @Test func RoomCodeInUseIsNotGivenTwice() async throws {
        var codes = ["111111", "111111", "222222"]
        let makeRoomCode = { codes.removeFirst() }

        let first = try await Phone("_one", makeRoomCode: makeRoomCode)
            .CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)
        let second = try await Phone("_two", makeRoomCode: makeRoomCode)
            .CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)

        #expect(first.state.trip.roomCode == "111111")
        #expect(second.state.trip.roomCode == "222222")
    }

    @Test func CreatedTripIsStoredAsCloudKitRecords() async throws {
        let session = try await Phone("_agus0001").CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)

        let types = server.records.values.map(\.recordType).sorted()
        #expect(types == ["Participant", "Route", "Trip", "Waypoint", "Waypoint", "Waypoint"])
        let trip = try #require(server.records[TripRecordMapper.RecordID(session.state.trip.id)])
        #expect(trip["roomCode"] as? String == "897654")
    }

    @Test func PhoneWithoutICloudCannotCreateATrip() async {
        await #expect(throws: TripServiceError.notSignedInToICloud) {
            try await Phone(nil).CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)
        }
    }

    @Test func PhoneWithoutICloudCannotJoin() async throws {
        let created = try await Phone("_agus0001").CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)

        await #expect(throws: TripServiceError.notSignedInToICloud) {
            try await Phone(nil).JoinTrip(roomCode: created.state.trip.roomCode, profile: nil)
        }
    }

    @Test func NoNetworkIsReportedClearly() async throws {
        let created = try await Phone("_agus0001").CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)
        server.failure = CKError(.networkUnavailable)

        await #expect(throws: TripServiceError.noNetwork) {
            try await Phone("_budi7F3A").JoinTrip(roomCode: created.state.trip.roomCode, profile: nil)
        }
    }

    @Test func UpdatesKeepGoingWhileTheNetworkIsDown() async throws {
        let agus = Phone("_agus0001")
        let created = try await agus.CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)
        let tripID = created.state.trip.id
        var updates = Phone("_budi7F3A").TripUpdates(tripID: tripID).makeAsyncIterator()
        let first = await updates.next()

        server.failure = CKError(.networkUnavailable)
        try await Task.sleep(for: .milliseconds(30))
        server.failure = nil
        try await agus.StartTrip(tripID: tripID, by: created.myParticipantID)
        let second = await updates.next()

        #expect(first?.trip.status == .lobby)
        #expect(second?.trip.status == .inTrip)
    }

    @Test func UpdatesDoNotRepeatAnUnchangedTrip() async throws {
        let agus = Phone("_agus0001")
        let created = try await agus.CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)
        let tripID = created.state.trip.id
        var updates = Phone("_budi7F3A").TripUpdates(tripID: tripID).makeAsyncIterator()

        _ = await updates.next()
        try await Task.sleep(for: .milliseconds(30))
        try await agus.StartTrip(tripID: tripID, by: created.myParticipantID)
        let next = await updates.next()

        #expect(next?.trip.status == .inTrip)
    }

    @Test func LocationIsSavedWithOneRequest() async throws {
        let agus = Phone("_agus0001")
        let created = try await agus.CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)
        let reads = server.handOutCount
        let saves = server.saveCount
        let update = LocationUpdate(
            coordinate: TripFixtures.ciputraWorld,
            speedKmh: 40,
            motionState: .driving,
            recordedAt: TripFixtures.now
        )

        try await agus.UpdateLocation(update, participantID: created.myParticipantID, tripID: created.state.trip.id)

        #expect(server.handOutCount == reads)
        #expect(server.saveCount == saves + 1)
        let me = try await agus.FetchTrip(tripID: created.state.trip.id).participants.first
        #expect(me?.coordinate == TripFixtures.ciputraWorld)
        #expect(me?.displayName == "Member 0001")
    }
}
