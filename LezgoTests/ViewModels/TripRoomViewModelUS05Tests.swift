//
//  TripRoomViewModelUS05Tests.swift
//  LezgoTests
//
//  Created by Oky Faishal on 27/10/26.
//

import CoreLocation
import Foundation
import Testing
@testable import Lezgo

@MainActor
struct TripRoomViewModelUS05Tests {
    @Test func CanStartTripRequiresNonLeaderParticipants() {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let state = SampleTrip.State(status: .lobby)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: state
        )

        #expect(viewModel.canStartTrip == true)

        let agusOnlyState = TripState(
            trip: state.trip,
            waypoints: state.waypoints,
            participants: state.participants.filter { $0.id == SampleTrip.agusID },
            route: state.route
        )
        let aloneViewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: agusOnlyState
        )
        #expect(aloneViewModel.canStartTrip == false)

        let memberViewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            initialState: state
        )
        #expect(memberViewModel.canStartTrip == false)
    }

    @Test func MemberCannotToggleSelectionMode() {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.budiID)
        let state = SampleTrip.State(status: .lobby)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            initialState: state
        )

        viewModel.ToggleSelectionMode()
        #expect(viewModel.isSelectionMode == false)
    }

    @Test func IsParticipantReadyWhenNearbyAndOnline() throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let state = SampleTrip.State(status: .lobby)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: state
        )

        let startPoint = try #require(viewModel.startPoint)
        let now = Date.now

        let readyParticipant = Participant(
            id: UUID(),
            tripID: SampleTrip.tripID,
            userRecordID: "user_ready",
            displayName: "Ready Driver",
            carDescription: "Car",
            coordinate: startPoint.coordinate,
            speedKmh: 0,
            motionState: .stopped,
            alert: .none,
            lastSeenAt: now
        )
        #expect(viewModel.IsParticipantReady(readyParticipant, at: now) == true)
    }

    @Test func IsParticipantNotReadyWhenFarAway() throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let state = SampleTrip.State(status: .lobby)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: state
        )

        let startPoint = try #require(viewModel.startPoint)
        let now = Date.now

        let farCoordinate = Coordinate(
            latitude: startPoint.coordinate.latitude + 0.05,
            longitude: startPoint.coordinate.longitude
        )
        let farParticipant = Participant(
            id: UUID(),
            tripID: SampleTrip.tripID,
            userRecordID: "user_far",
            displayName: "Far Driver",
            carDescription: "Car",
            coordinate: farCoordinate,
            speedKmh: 0,
            motionState: .stopped,
            alert: .none,
            lastSeenAt: now
        )
        #expect(viewModel.IsParticipantReady(farParticipant, at: now) == false)
    }

    @Test func IsParticipantNotReadyWhenOfflineOrMissingCoord() throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let state = SampleTrip.State(status: .lobby)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: state
        )

        let startPoint = try #require(viewModel.startPoint)
        let now = Date.now

        // 1. Offline (> 120s)
        let offlineParticipant = Participant(
            id: UUID(),
            tripID: SampleTrip.tripID,
            userRecordID: "user_offline",
            displayName: "Offline Driver",
            carDescription: "Car",
            coordinate: startPoint.coordinate,
            speedKmh: 0,
            motionState: .stopped,
            alert: .none,
            lastSeenAt: now.addingTimeInterval(-180)
        )
        #expect(viewModel.IsParticipantReady(offlineParticipant, at: now) == false)

        // 2. Missing coordinate
        let noCoordParticipant = Participant(
            id: UUID(),
            tripID: SampleTrip.tripID,
            userRecordID: "user_no_coord",
            displayName: "No Location",
            carDescription: "Car",
            coordinate: nil,
            speedKmh: 0,
            motionState: .stopped,
            alert: .none,
            lastSeenAt: now
        )
        #expect(viewModel.IsParticipantReady(noCoordParticipant, at: now) == false)
    }

    @Test func IsEveryoneReadyAndStartTripAlertTitle() {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let state = SampleTrip.State(status: .lobby)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: state
        )

        // In SampleTrip.State, Citra is offline (>120s ago), so not everyone is ready
        #expect(viewModel.isEveryoneReady == false)
        #expect(
            viewModel.startTripConfirmationTitle
            == "Some participants are not yet ready, are you sure you want to start the trip?"
        )

        // Make all participants ready
        guard let startCoord = viewModel.startPoint?.coordinate else { return }
        let now = Date.now
        let allReadyParticipants = state.participants.map { participant in
            var updated = participant
            updated.coordinate = startCoord
            updated.lastSeenAt = now
            return updated
        }
        let allReadyState = TripState(
            trip: state.trip,
            waypoints: state.waypoints,
            participants: allReadyParticipants,
            route: state.route
        )
        let allReadyViewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: allReadyState
        )

        #expect(allReadyViewModel.isEveryoneReady == true)
        #expect(allReadyViewModel.startTripConfirmationTitle == "Start trip?")
    }

    @Test func ListenDetectsWhenCurrentMemberIsRemoved() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.budiID)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID
        )

        let task = Task {
            await viewModel.Listen()
        }

        for _ in 0..<10 {
            if viewModel.state != nil { break }
            try await Task.sleep(for: .milliseconds(50))
        }

        #expect(viewModel.state != nil)
        #expect(viewModel.wasRemovedFromTrip == false)

        // Leader removes Budi
        try await service.RemoveParticipants([SampleTrip.budiID], tripID: SampleTrip.tripID, by: SampleTrip.agusID)

        for _ in 0..<10 {
            if viewModel.wasRemovedFromTrip { break }
            try await Task.sleep(for: .milliseconds(50))
        }

        #expect(viewModel.wasRemovedFromTrip == true)
        task.cancel()
    }

    @Test func LeaderCannotRemoveSelf() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let state = SampleTrip.State(status: .lobby)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: state
        )

        try await viewModel.RemoveParticipant(id: SampleTrip.agusID)

        let updated = try await service.FetchTrip(tripID: SampleTrip.tripID)
        #expect(updated.participants.contains(where: { $0.id == SampleTrip.agusID }))
    }

    @Test func LeaderCannotSetLeaderToSelf() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let state = SampleTrip.State(status: .lobby)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: state
        )

        let agus = try #require(state.participants.first(where: { $0.id == SampleTrip.agusID }))
        try await viewModel.SetLeader(to: agus)

        let updated = try await service.FetchTrip(tripID: SampleTrip.tripID)
        #expect(updated.trip.leaderParticipantID == SampleTrip.agusID)
    }
}
