//
//  TripRoomViewModelSoloStartTests.swift
//  LezgoTests
//
//  Created by Nathan on 23/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The leader may start a trip alone after a confirmation (`specs/UserStories.md` → US-05, "Leader alone").
@MainActor
struct TripRoomViewModelSoloStartTests {
    @Test func LeaderAloneSeesTheSoloStartTitle() {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let state = SampleTrip.State(status: .lobby)
        let agusOnlyState = TripState(
            trip: state.trip,
            waypoints: state.waypoints,
            participants: state.participants.filter { $0.id == SampleTrip.agusID },
            route: state.route
        )
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: agusOnlyState
        )

        #expect(viewModel.isLeaderAlone == true)
        // Alone wins over "not yet ready": being alone is the bigger surprise, and the leader's own readiness
        // is something they can see for themselves.
        #expect(
            viewModel.startTripConfirmationTitle
            == "You are the only one in this trip. Start the trip alone?"
        )
    }

    @Test func LeaderWithMembersIsNotAlone() {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: SampleTrip.State(status: .lobby)
        )

        #expect(viewModel.isLeaderAlone == false)
    }

    @Test func NoTripLoadedIsNotAlone() {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID
        )

        #expect(viewModel.isLeaderAlone == false)
        #expect(viewModel.canStartTrip == false)
    }
}
