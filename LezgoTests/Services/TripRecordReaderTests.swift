//
//  TripRecordReaderTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 26/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// How the live service reads a trip between member queries (#69: faster reads by record ID).
struct TripRecordReaderTests {
    let server = FakeCloudServer()
    let agus: LiveTripService
    let budi: LiveTripService
    let reader: TripRecordReader

    init() {
        agus = LiveTripService(database: FakeCloudDatabase(server: server, userRecordName: "_agus0001"))
        budi = LiveTripService(database: FakeCloudDatabase(server: server, userRecordName: "_budi7F3A"))
        reader = TripRecordReader(database: FakeCloudDatabase(server: server, userRecordName: "_reader"))
    }

    /// Agus creates a trip on the road and Budi joins; returns the trip as it is now and Budi's ID.
    private func MakeTrip() async throws -> (state: TripState, budiID: UUID) {
        let created = try await agus.CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)
        let joined = try await budi.JoinTrip(roomCode: created.state.trip.roomCode, profile: nil)
        try await agus.StartTrip(tripID: created.state.trip.id, by: created.myParticipantID)
        return (try await agus.FetchTrip(tripID: created.state.trip.id), joined.myParticipantID)
    }

    private var update: LocationUpdate {
        LocationUpdate(
            coordinate: TripFixtures.ciputraWorld,
            speedKmh: 40,
            motionState: .driving,
            recordedAt: TripFixtures.now
        )
    }

    @Test func KnownMembersAreReadByIDWithoutAQuery() async throws {
        let (state, budiID) = try await MakeTrip()
        try await budi.UpdateLocation(update, participantID: budiID, tripID: state.trip.id)
        let queries = server.queryCount

        let next = try await reader.LoadState(tripID: state.trip.id, reusing: state, discoverMembers: false)

        #expect(server.queryCount == queries)
        #expect(next.participants.first { $0.id == budiID }?.coordinate == TripFixtures.ciputraWorld)
        #expect(next.participants.map(\.id) == state.participants.map(\.id))
    }

    @Test func NewMemberAppearsWhenMembersAreDiscovered() async throws {
        let (state, _) = try await MakeTrip()
        _ = try await LiveTripService(database: FakeCloudDatabase(server: server, userRecordName: "_citra42C"))
            .JoinTrip(roomCode: state.trip.roomCode, profile: nil)

        let known = try await reader.LoadState(tripID: state.trip.id, reusing: state, discoverMembers: false)
        let discovered = try await reader.LoadState(tripID: state.trip.id, reusing: state, discoverMembers: true)

        #expect(known.participants.count == 2)
        #expect(discovered.participants.count == 3)
    }

    @Test func MemberWhoLeftDisappearsWithoutAQuery() async throws {
        let (state, budiID) = try await MakeTrip()
        try await budi.ExitTrip(tripID: state.trip.id, participantID: budiID)

        let next = try await reader.LoadState(tripID: state.trip.id, reusing: state, discoverMembers: false)

        #expect(next.participants.contains { $0.id == budiID } == false)
    }

    @Test func StrayPositionOfARemovedMemberIsIgnored() async throws {
        let (state, budiID) = try await MakeTrip()
        try await agus.RemoveParticipants([budiID], tripID: state.trip.id, by: state.trip.leaderParticipantID)
        try await budi.UpdateLocation(update, participantID: budiID, tripID: state.trip.id)

        let next = try await reader.LoadState(tripID: state.trip.id, reusing: state, discoverMembers: false)

        #expect(next.participants.contains { $0.id == budiID } == false)
    }
}
