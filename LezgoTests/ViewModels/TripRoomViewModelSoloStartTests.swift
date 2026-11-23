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
    @Test func LeaderAloneAndNotReadySeesTheSoloStartTitle() {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let state = SampleTrip.State(status: .lobby)
        // No location yet, so the leader is not ready to start.
        let agusNotReady = state.participants.filter { $0.id == SampleTrip.agusID }.map { participant in
            var notReady = participant
            notReady.coordinate = nil
            return notReady
        }
        let agusOnlyState = TripState(
            trip: state.trip,
            waypoints: state.waypoints,
            participants: agusNotReady,
            route: state.route
        )
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: agusOnlyState
        )

        #expect(viewModel.isLeaderAlone == true)
        #expect(viewModel.isEveryoneReady == false)
        // Alone wins over "not yet ready": being alone is the bigger surprise, and the leader's own readiness
        // is something they can see for themselves.
        #expect(
            viewModel.startTripConfirmationTitle
            == "You are the only one in this trip. Start the trip alone?"
        )
    }

    @Test func LeaderAloneAndReadySeesTheSoloStartTitle() {
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
        #expect(viewModel.isEveryoneReady == true)
        #expect(
            viewModel.startTripConfirmationTitle
            == "You are the only one in this trip. Start the trip alone?"
        )
    }

    @Test func LeaderWithNoParticipantsListedIsNotAlone() {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let state = SampleTrip.State(status: .lobby)
        let emptyState = TripState(
            trip: state.trip,
            waypoints: state.waypoints,
            participants: [],
            route: state.route
        )
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: emptyState
        )

        #expect(viewModel.isLeaderAlone == false)
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
