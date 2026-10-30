//
//  TripRoomViewModelStartTripTests.swift
//  LezgoTests
//
//  Created by Oky Faishal on 29/10/26.
//

import Foundation
import Testing
@testable import Lezgo

@MainActor
struct TripRoomViewModelStartTripTests {
    @Test func HasTripStartedIsFalseInTheLobby() {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let state = SampleTrip.State(status: .lobby)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: state,
            activeTripStorage: FakeActiveTripStorage()
        )

        #expect(viewModel.hasTripStarted == false)
    }

    @Test func LeaderStartTripSetsHasTripStarted() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let state = SampleTrip.State(status: .lobby)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: state,
            activeTripStorage: FakeActiveTripStorage()
        )

        try await viewModel.StartTrip()

        #expect(viewModel.hasTripStarted == true)
    }

    @Test func MemberMovesToMapWhenSnapshotIsInTrip() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.budiID)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            activeTripStorage: FakeActiveTripStorage()
        )

        let task = Task {
            await viewModel.Listen()
        }

        // Wait until the view model gets its first snapshot in lobby
        for _ in 0..<20 {
            if viewModel.state != nil { break }
            try await Task.sleep(for: .milliseconds(50))
        }

        #expect(viewModel.state != nil)
        #expect(viewModel.hasTripStarted == false)

        // Leader starts the trip through the service
        try await service.StartTrip(tripID: SampleTrip.tripID, by: SampleTrip.agusID)

        // Member's listener receives the IN_TRIP snapshot and sets hasTripStarted
        for _ in 0..<20 {
            if viewModel.hasTripStarted { break }
            try await Task.sleep(for: .milliseconds(50))
        }

        #expect(viewModel.hasTripStarted == true)
        task.cancel()
    }

    @Test func FirstSnapshotAlreadyInTripSetsHasTripStarted() async throws {
        let service = SampleTrip.Service(status: .inTrip, me: SampleTrip.budiID)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            activeTripStorage: FakeActiveTripStorage()
        )

        let task = Task {
            await viewModel.Listen()
        }

        for _ in 0..<20 {
            if viewModel.hasTripStarted { break }
            try await Task.sleep(for: .milliseconds(50))
        }

        #expect(viewModel.hasTripStarted == true)
        task.cancel()
    }

    @Test func InitialStateInTripSetsHasTripStarted() {
        let service = SampleTrip.Service(status: .inTrip, me: SampleTrip.budiID)
        let state = SampleTrip.State(status: .inTrip)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            initialState: state,
            activeTripStorage: FakeActiveTripStorage()
        )

        #expect(viewModel.hasTripStarted == true)
    }

    @Test func SecondStartTripTapIsIgnored() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let state = SampleTrip.State(status: .lobby)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: state,
            activeTripStorage: FakeActiveTripStorage()
        )

        try await viewModel.StartTrip()
        #expect(viewModel.hasTripStarted == true)

        // Second call must not throw even though service would reject if called again
        try await viewModel.StartTrip()
        #expect(viewModel.hasTripStarted == true)

        let updated = try await service.FetchTrip(tripID: SampleTrip.tripID)
        #expect(updated.trip.status == .inTrip)
    }

    @Test func CanStartTripIsFalseAfterStart() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let state = SampleTrip.State(status: .lobby)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: state,
            activeTripStorage: FakeActiveTripStorage()
        )

        #expect(viewModel.canStartTrip == true)
        try await viewModel.StartTrip()
        #expect(viewModel.canStartTrip == false)
    }

    @Test func StartTripFailureKeepsLobby() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        service.simulatedFailure = .noNetwork
        let state = SampleTrip.State(status: .lobby)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: state,
            activeTripStorage: FakeActiveTripStorage()
        )

        await #expect(throws: TripServiceError.self) {
            try await viewModel.StartTrip()
        }

        #expect(viewModel.hasTripStarted == false)
        #expect(viewModel.isStartingTrip == false)

        service.simulatedFailure = nil
        let fresh = try await service.FetchTrip(tripID: SampleTrip.tripID)
        #expect(fresh.trip.status == .lobby)
    }

    @Test func RemovedMemberDoesNotSetHasTripStarted() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.budiID)
        // Leader removes Budi and starts the trip
        try await service.RemoveParticipants([SampleTrip.budiID], tripID: SampleTrip.tripID, by: SampleTrip.agusID)
        try await service.StartTrip(tripID: SampleTrip.tripID, by: SampleTrip.agusID)

        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            activeTripStorage: FakeActiveTripStorage()
        )

        let task = Task {
            await viewModel.Listen()
        }

        for _ in 0..<20 {
            if viewModel.wasRemovedFromTrip { break }
            try await Task.sleep(for: .milliseconds(50))
        }

        #expect(viewModel.wasRemovedFromTrip == true)
        #expect(viewModel.hasTripStarted == false)
        task.cancel()
    }

    /// A member who exited is no longer in the trip, so a start that arrives afterwards must not open the map.
    @Test func MemberWhoExitedIsNotMovedToTheMap() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.budiID)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            activeTripStorage: FakeActiveTripStorage()
        )

        let task = Task {
            await viewModel.Listen()
        }

        for _ in 0..<20 {
            if viewModel.state != nil { break }
            try await Task.sleep(for: .milliseconds(50))
        }

        try await viewModel.LeaveTrip()
        try await service.StartTrip(tripID: SampleTrip.tripID, by: SampleTrip.agusID)

        for _ in 0..<20 {
            if viewModel.tripStatus == .inTrip { break }
            try await Task.sleep(for: .milliseconds(50))
        }

        #expect(viewModel.tripStatus == .inTrip)
        #expect(viewModel.hasTripStarted == false)
        #expect(viewModel.wasRemovedFromTrip == false)
        task.cancel()
    }
}
