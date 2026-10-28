//
//  SampleTripTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 26/10/26.
//

#if DEBUG
import Foundation
import Testing
@testable import Lezgo

struct SampleTripTests {
    @Test func SampleTripHasTheUserStoryGroup() {
        let state = SampleTrip.State(status: .lobby, now: TripFixtures.now)

        #expect(state.participants.map(\.displayName) == ["Agus", "Budi", "Citra"])
        #expect(state.leader?.id == SampleTrip.agusID)
        #expect(state.waypoints.map(\.name) == ["Tunjungan Plaza", "Ciputra World", "Pakuwon mall"])
        #expect(state.route?.polyline.isEmpty == false)
    }

    @Test func CitraIsOffline() throws {
        let state = SampleTrip.State(status: .inTrip, now: TripFixtures.now)

        let citra = try #require(state.participants.first { $0.id == SampleTrip.citraID })
        #expect(citra.IsOnline(at: TripFixtures.now) == false)
    }

    @Test(arguments: [TripStatus.lobby, .inTrip])
    func StatusMatchesTheTripOnTheRoad(status: TripStatus) {
        let trip = SampleTrip.State(status: status, now: TripFixtures.now).trip

        #expect(trip.status == status)
        #expect(trip.currentWaypointIndex == (status == .inTrip ? 1 : 0))
    }

    @Test func ServiceActsAsThePhoneOfTheGivenPerson() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.budiID)

        let session = try await service.JoinTrip(roomCode: SampleTrip.roomCode, profile: nil)

        #expect(session.myParticipantID == SampleTrip.budiID)
        #expect(session.state.participants.count == 3)
    }

    @Test func LeaderPhoneCanStartTheSampleTrip() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)

        try await service.StartTrip(tripID: SampleTrip.tripID, by: SampleTrip.agusID)

        #expect(try await service.FetchTrip(tripID: SampleTrip.tripID).trip.status == .inTrip)
    }
}
#endif
