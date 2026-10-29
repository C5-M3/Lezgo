//
//  TripRoomViewModelLeaveTests.swift
//  LezgoTests
//
//  Created by Oky Faishal on 29/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// Exit from the Trip Room before the trip starts (`specs/UserStories.md` → US-07, "Leave and end").
@MainActor
struct TripRoomViewModelLeaveTests {
    private func Summary(me: UUID) -> ActiveTripSummary {
        ActiveTripSummary(
            tripID: SampleTrip.tripID,
            myParticipantID: me,
            roomCode: "897654",
            startName: "Monas",
            destinationName: "Puncak"
        )
    }

    private func MakeViewModel(
        me: UUID,
        service: any TripService,
        storage: FakeActiveTripStorage,
        state: TripState = SampleTrip.State(status: .lobby)
    ) -> TripRoomViewModel {
        TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: me,
            initialState: state,
            activeTripStorage: storage
        )
    }

    // MARK: Asking

    @Test func MemberIsAskedToExitTheRoom() {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.budiID)
        let viewModel = MakeViewModel(me: SampleTrip.budiID, service: service, storage: FakeActiveTripStorage())

        #expect(viewModel.leaveConfirmation == .exitRoom)
    }

    @Test func LeaderIsWarnedThatTheTripEndsForEveryone() {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let viewModel = MakeViewModel(me: SampleTrip.agusID, service: service, storage: FakeActiveTripStorage())

        #expect(viewModel.leaveConfirmation == .endTripForEveryone)
    }

    /// Handing over the lead is how a leader leaves without ending the trip (US-05).
    @Test func FormerLeaderIsAskedToExitTheRoomAfterHandingOver() {
        var handedOver = SampleTrip.State(status: .lobby)
        handedOver.trip.leaderParticipantID = SampleTrip.budiID
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let viewModel = MakeViewModel(
            me: SampleTrip.agusID, service: service, storage: FakeActiveTripStorage(), state: handedOver
        )

        #expect(viewModel.leaveConfirmation == .exitRoom)
    }

    // MARK: Leaving

    @Test func MemberExitRemovesThemAndClearsTheTripFromThePhone() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.budiID)
        let storage = FakeActiveTripStorage(initial: Summary(me: SampleTrip.budiID))
        let viewModel = MakeViewModel(me: SampleTrip.budiID, service: service, storage: storage)

        try await viewModel.LeaveTrip()

        let updated = try await service.FetchTrip(tripID: SampleTrip.tripID)
        #expect(!updated.participants.contains { $0.id == SampleTrip.budiID })
        #expect(storage.LoadActiveTrip() == nil)
        #expect(viewModel.hasLeft)
    }

    @Test func LeaderExitCancelsTheTripAndClearsItFromThePhone() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let storage = FakeActiveTripStorage(initial: Summary(me: SampleTrip.agusID))
        let viewModel = MakeViewModel(me: SampleTrip.agusID, service: service, storage: storage)

        try await viewModel.LeaveTrip()

        let updated = try await service.FetchTrip(tripID: SampleTrip.tripID)
        #expect(updated.trip.status == .cancelled)
        #expect(storage.LoadActiveTrip() == nil)
    }

    /// Nobody is told they left while they are still in the trip, so the room stays and the trip stays saved.
    @Test func FailedExitKeepsTheTripOnThePhone() async {
        let service = MockTripService(states: [])
        service.failure = .noNetwork
        let storage = FakeActiveTripStorage(initial: Summary(me: SampleTrip.budiID))
        let viewModel = MakeViewModel(me: SampleTrip.budiID, service: service, storage: storage)

        await #expect(throws: TripServiceError.noNetwork) {
            try await viewModel.LeaveTrip()
        }

        #expect(storage.LoadActiveTrip() != nil)
        #expect(viewModel.hasLeft == false)
        #expect(viewModel.isLeaving == false)
    }

    /// Exit can be tapped again while the first request is on its way.
    @Test func ExitingAgainWhileLeavingSendsOneRequest() async throws {
        let service = MockTripService(states: [])
        let storage = FakeActiveTripStorage(initial: Summary(me: SampleTrip.budiID))
        let viewModel = MakeViewModel(me: SampleTrip.budiID, service: service, storage: storage)
        var wasLeavingDuringRequest = false
        service.whileLeaving = {
            wasLeavingDuringRequest = viewModel.isLeaving
            try? await viewModel.LeaveTrip()
        }

        try await viewModel.LeaveTrip()

        #expect(wasLeavingDuringRequest)
        #expect(service.exitedParticipantIDs == [SampleTrip.budiID])
        #expect(storage.clearCount == 1)
        #expect(viewModel.isLeaving == false)
    }
}
