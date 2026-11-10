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
        #expect(viewModel.wasCancelledByLeader == false)
        #expect(viewModel.confirmTitle == "Create a new trip?")
        #expect(viewModel.confirmMessage == nil)
        #expect(viewModel.cancelledTitle == "Trip Cancelled")
        #expect(viewModel.cancelledMessage == "Your last trip was cancelled by leader")
    }

    @Test("Route coordinates and duration text are exposed accurately")
    func routeCoordinatesAndDuration() {
        let coords = [
            Coordinate(latitude: -7.2858, longitude: 112.6318),
            Coordinate(latitude: -7.2872, longitude: 112.6780),
            Coordinate(latitude: -7.2923, longitude: 112.7190)
        ]
        var summary = makeMemberSummary()
        summary.routeCoordinates = coords
        summary.estimatedDuration = 75 * 60 // 1 hr 15 min

        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.budiID)
        let viewModel = DraftTripViewModel(summary: summary, tripService: service)

        #expect(viewModel.routeCoordinates == coords)
        #expect(viewModel.estimatedDuration == TimeInterval(75 * 60))
        #expect(viewModel.durationText == "1 hr 15 min")

        summary.estimatedDuration = 25 * 60 // 25 min
        let shortViewModel = DraftTripViewModel(summary: summary, tripService: service)
        #expect(shortViewModel.durationText == "25 min")
    }

    @Test("TapNewTrip presents confirmation dialog")
    func tapNewTripPresentsModal() {
        let summary = makeMemberSummary()
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.budiID)
        let viewModel = DraftTripViewModel(summary: summary, tripService: service)

        viewModel.TapNewTrip()
        #expect(viewModel.isConfirmingNewTrip == true)
    }

    @Test("Leader confirmation message contains ending trip notice")
    func leaderConfirmationMessage() {
        let summary = makeLeaderSummary()
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let viewModel = DraftTripViewModel(summary: summary, tripService: service)

        #expect(viewModel.isLeader == true)
        #expect(viewModel.confirmMessage == "Your current trip will end for everyone")
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
        #expect(viewModel.wasCancelledByLeader == false)
    }

    @Test("CheckServerStatus clears storage and presents cancelled notice for member when trip is ended or cancelled")
    func checkServerStatusEndedTrip() async {
        let summary = makeMemberSummary()
        let service = SampleTrip.Service(status: .ended, me: SampleTrip.budiID)
        let storage = FakeActiveTripStorage(initial: summary)
        let viewModel = DraftTripViewModel(summary: summary, tripService: service, storage: storage)

        let isOpen = await viewModel.CheckServerStatus()

        #expect(isOpen == false)
        #expect(storage.storedSummary == nil)
        #expect(storage.clearCount == 1)
        #expect(viewModel.wasCancelledByLeader == true)
    }

    @Test("CheckServerStatus clears storage but does not present cancelled notice for leader")
    func checkServerStatusCancelledTripForLeader() async {
        let summary = makeLeaderSummary()
        let service = SampleTrip.Service(status: .cancelled, me: SampleTrip.agusID)
        let storage = FakeActiveTripStorage(initial: summary)
        let viewModel = DraftTripViewModel(summary: summary, tripService: service, storage: storage)

        let isOpen = await viewModel.CheckServerStatus()

        #expect(isOpen == false)
        #expect(storage.storedSummary == nil)
        #expect(storage.clearCount == 1)
        #expect(viewModel.wasCancelledByLeader == false)
    }

    @Test("Listening updates the trip info when another participant leaves")
    func listeningUpdatesTripInfoWhenAnotherParticipantLeaves() async throws {
        let initialState = SampleTrip.State()
        let store = InMemoryTripStore(trips: [initialState])
        let service = InMemoryTripService(store: store, userRecordID: "_budi")
        let otherPhoneService = InMemoryTripService(store: store, userRecordID: "_citra")
        let summary = ActiveTripSummary.From(
            session: TripSession(myParticipantID: SampleTrip.budiID, state: initialState)
        )
        let viewModel = DraftTripViewModel(summary: summary, tripService: service)

        let listeningTask = Task { await viewModel.Listen() }
        await Task.yield()
        try await otherPhoneService.ExitTrip(tripID: SampleTrip.tripID, participantID: SampleTrip.citraID)

        for _ in 0..<10 where viewModel.memberCount != 4 {
            await Task.yield()
        }

        #expect(viewModel.tripInfoText == "4 people · Lobby")
        listeningTask.cancel()
    }

    @Test("Listening presents cancelled notice and clears storage when leader ends or cancels the trip")
    func listeningPresentsCancelledNoticeWhenLeaderCancelsTrip() async throws {
        let initialState = SampleTrip.State()
        let store = InMemoryTripStore(trips: [initialState])
        let memberService = InMemoryTripService(store: store, userRecordID: "_budi")
        let leaderService = InMemoryTripService(store: store, userRecordID: "_agus")
        let summary = ActiveTripSummary.From(
            session: TripSession(myParticipantID: SampleTrip.budiID, state: initialState)
        )
        let storage = FakeActiveTripStorage(initial: summary)
        let viewModel = DraftTripViewModel(summary: summary, tripService: memberService, storage: storage)

        let listeningTask = Task { await viewModel.Listen() }
        await Task.yield()

        // Leader creates a new trip, calling EndTrip on the existing trip
        try await leaderService.EndTrip(tripID: SampleTrip.tripID, by: SampleTrip.agusID)

        for _ in 0..<10 where !viewModel.wasCancelledByLeader {
            await Task.yield()
        }

        #expect(viewModel.wasCancelledByLeader == true)
        #expect(storage.storedSummary == nil)
        #expect(storage.clearCount == 1)
        listeningTask.cancel()
    }
}
