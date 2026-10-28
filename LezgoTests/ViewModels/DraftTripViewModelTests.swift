//
//  DraftTripViewModelTests.swift
//  LezgoTests
//
//  Created by Rizal Pratama on 27/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// A test double for ActiveTripStorage.
final class FakeActiveTripStorage: ActiveTripStorage, @unchecked Sendable {
    var storedSummary: ActiveTripSummary?
    var clearCount: Int = 0

    init(initial: ActiveTripSummary? = nil) {
        self.storedSummary = initial
    }

    func SaveActiveTrip(_ summary: ActiveTripSummary) {
        storedSummary = summary
    }

    func LoadActiveTrip() -> ActiveTripSummary? {
        storedSummary
    }

    func ClearActiveTrip() {
        storedSummary = nil
        clearCount += 1
    }
}

@Suite("DraftTripViewModel Tests")
@MainActor
struct DraftTripViewModelTests {

    private func makeMemberSummary() -> ActiveTripSummary {
        ActiveTripSummary(
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            roomCode: SampleTrip.roomCode,
            startName: "Universitas Ciputra",
            destinationName: "Ciputra World",
            distanceText: "9 km",
            memberNames: ["Nathan", "Mathew"],
            status: .lobby,
            isLeader: false
        )
    }

    private func makeLeaderSummary() -> ActiveTripSummary {
        ActiveTripSummary(
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            roomCode: SampleTrip.roomCode,
            startName: "Universitas Ciputra",
            destinationName: "Ciputra World",
            distanceText: "9 km",
            memberNames: ["Agus", "Budi"],
            status: .lobby,
            isLeader: true
        )
    }

    @Test("Initial state reflects summary information accurately")
    func initialState() {
        let summary = makeMemberSummary()
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.budiID)
        let storage = FakeActiveTripStorage(initial: summary)
        let viewModel = DraftTripViewModel(summary: summary, tripService: service, storage: storage)

        #expect(viewModel.startPointName == "Universitas Ciputra")
        #expect(viewModel.destinationName == "Ciputra World")
        #expect(viewModel.distanceText == "9 km")
        #expect(viewModel.membersText == "Nathan, Mathew")
        #expect(viewModel.isLeader == false)
        #expect(viewModel.isConfirmingNewTrip == false)
        #expect(viewModel.confirmTitle == "Create a new trip?")
        #expect(viewModel.confirmMessage == nil)
    }

    @Test("TapNewTrip presents confirmation dialog")
    func tapNewTripPresentsModal() {
        let summary = makeMemberSummary()
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.budiID)
        let viewModel = DraftTripViewModel(summary: summary, tripService: service)

        viewModel.TapNewTrip()
        #expect(viewModel.isConfirmingNewTrip == true)
    }

    @Test("DismissConfirmation hides confirmation dialog")
    func dismissConfirmation() {
        let summary = makeMemberSummary()
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.budiID)
        let viewModel = DraftTripViewModel(summary: summary, tripService: service)

        viewModel.TapNewTrip()
        #expect(viewModel.isConfirmingNewTrip == true)

        viewModel.DismissConfirmation()
        #expect(viewModel.isConfirmingNewTrip == false)
    }

    @Test("Leader confirmation message contains ending trip notice")
    func leaderConfirmationMessage() {
        let summary = makeLeaderSummary()
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let viewModel = DraftTripViewModel(summary: summary, tripService: service)

        #expect(viewModel.isLeader == true)
        #expect(viewModel.confirmMessage == "Your current trip will end for everyone.")
    }

    @Test("Member confirming new trip exits the trip and clears storage")
    func memberConfirmNewTrip() async {
        let summary = makeMemberSummary()
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.budiID)
        let storage = FakeActiveTripStorage(initial: summary)
        let viewModel = DraftTripViewModel(summary: summary, tripService: service, storage: storage)

        viewModel.TapNewTrip()
        let success = await viewModel.ConfirmNewTrip()

        #expect(success == true)
        #expect(viewModel.isConfirmingNewTrip == false)
        #expect(storage.storedSummary == nil)
        #expect(storage.clearCount == 1)

        // Member Budi should now be removed from the trip
        let updatedState = try? await service.FetchTrip(tripID: SampleTrip.tripID)
        let budiPresent = updatedState?.participants.contains { $0.id == SampleTrip.budiID } ?? false
        #expect(budiPresent == false)
    }

    @Test("Leader confirming new trip ends the trip and clears storage")
    func leaderConfirmNewTrip() async {
        let summary = makeLeaderSummary()
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let storage = FakeActiveTripStorage(initial: summary)
        let viewModel = DraftTripViewModel(summary: summary, tripService: service, storage: storage)

        viewModel.TapNewTrip()
        let success = await viewModel.ConfirmNewTrip()

        #expect(success == true)
        #expect(viewModel.isConfirmingNewTrip == false)
        #expect(storage.storedSummary == nil)
        #expect(storage.clearCount == 1)

        // Trip should now be cancelled/ended
        let updatedState = try? await service.FetchTrip(tripID: SampleTrip.tripID)
        #expect(updatedState?.trip.status == .cancelled || updatedState?.trip.status == .ended)
    }

    @Test("CheckServerStatus updates summary when trip is still open")
    func checkServerStatusOpenTrip() async {
        let summary = makeMemberSummary()
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.budiID)
        let storage = FakeActiveTripStorage(initial: summary)
        let viewModel = DraftTripViewModel(summary: summary, tripService: service, storage: storage)

        let isOpen = await viewModel.CheckServerStatus()

        #expect(isOpen == true)
        #expect(storage.storedSummary != nil)
    }

    @Test("CheckServerStatus clears storage and returns false when trip is ended")
    func checkServerStatusEndedTrip() async {
        let summary = makeMemberSummary()
        let service = SampleTrip.Service(status: .ended, me: SampleTrip.budiID)
        let storage = FakeActiveTripStorage(initial: summary)
        let viewModel = DraftTripViewModel(summary: summary, tripService: service, storage: storage)

        let isOpen = await viewModel.CheckServerStatus()

        #expect(isOpen == false)
        #expect(storage.storedSummary == nil)
        #expect(storage.clearCount == 1)
    }
}
