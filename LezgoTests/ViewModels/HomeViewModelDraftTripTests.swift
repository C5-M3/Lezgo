//
//  HomeViewModelDraftTripTests.swift
//  LezgoTests
//
//  Created by Muhammad Rizal Pratama on 30/10/26.
//

import CoreLocation
import Foundation
import MapKit
import Testing
@testable import Lezgo

@MainActor
@Suite("HomeViewModel Draft Trip Tests")
struct HomeViewModelDraftTripTests {
    @Test("continueDraftTrip transitions from draft to activeTripSession for lobby status")
    func continueDraftTripLobby() async {
        let mockMap = MockMapService()
        let mockSearch = MockLocationSearchService()
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.budiID)
        let sampleDraft = ActiveTripSummary(
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            roomCode: SampleTrip.roomCode,
            startName: "Start",
            destinationName: "End",
            memberNames: ["Budi"],
            status: .lobby,
            isLeader: false
        )
        let fakeStorage = FakeActiveTripStorage(initial: sampleDraft)
        let viewModel = HomeViewModel(mapService: mockMap, searchService: mockSearch, activeTripStorage: fakeStorage)

        #expect(viewModel.activeDraftTrip != nil)
        await viewModel.continueDraftTrip(tripService: service)

        #expect(viewModel.activeDraftTrip == nil)
        #expect(viewModel.activeTripSession != nil)
        #expect(viewModel.activeMapSession == nil)
        #expect(viewModel.lastTripEndedNotice == nil)
        #expect(viewModel.activeTripSession?.state.trip.id == SampleTrip.tripID)
    }

    @Test("continueDraftTrip navigates directly to activeMapSession for inTrip status")
    func continueDraftTripInTrip() async {
        let mockMap = MockMapService()
        let mockSearch = MockLocationSearchService()
        let service = SampleTrip.Service(status: .inTrip, me: SampleTrip.budiID)
        let sampleDraft = ActiveTripSummary(
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            roomCode: SampleTrip.roomCode,
            startName: "Start",
            destinationName: "End",
            memberNames: ["Budi"],
            status: .inTrip,
            isLeader: false
        )
        let fakeStorage = FakeActiveTripStorage(initial: sampleDraft)
        let viewModel = HomeViewModel(mapService: mockMap, searchService: mockSearch, activeTripStorage: fakeStorage)

        #expect(viewModel.activeDraftTrip != nil)
        await viewModel.continueDraftTrip(tripService: service)

        #expect(viewModel.activeDraftTrip == nil)
        #expect(viewModel.activeTripSession == nil)
        #expect(viewModel.activeMapSession != nil)
        #expect(viewModel.lastTripEndedNotice == nil)
        #expect(viewModel.activeMapSession?.state.trip.id == SampleTrip.tripID)
    }

    @Test("continueDraftTrip clears storage and sets error banner notice when trip has ended")
    func continueDraftTripEnded() async {
        let mockMap = MockMapService()
        let mockSearch = MockLocationSearchService()
        let service = SampleTrip.Service(status: .ended, me: SampleTrip.budiID)
        let sampleDraft = ActiveTripSummary(
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            roomCode: SampleTrip.roomCode,
            startName: "Start",
            destinationName: "End",
            memberNames: ["Budi"],
            status: .lobby,
            isLeader: false
        )
        let fakeStorage = FakeActiveTripStorage(initial: sampleDraft)
        let viewModel = HomeViewModel(mapService: mockMap, searchService: mockSearch, activeTripStorage: fakeStorage)

        #expect(viewModel.activeDraftTrip != nil)
        await viewModel.continueDraftTrip(tripService: service)

        #expect(viewModel.activeDraftTrip == nil)
        #expect(viewModel.activeTripSession == nil)
        #expect(viewModel.activeMapSession == nil)
        #expect(fakeStorage.storedSummary == nil)
        #expect(viewModel.lastTripEndedNotice == "Your last trip has ended.")
    }

    @Test("continueDraftTrip clears storage and sets error banner notice when trip is not found")
    func continueDraftTripNotFound() async {
        let mockMap = MockMapService()
        let mockSearch = MockLocationSearchService()
        let emptyStore = InMemoryTripStore(trips: [])
        let service = InMemoryTripService(store: emptyStore, userRecordID: "_budi")
        let sampleDraft = ActiveTripSummary(
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            roomCode: SampleTrip.roomCode,
            startName: "Start",
            destinationName: "End",
            memberNames: ["Budi"],
            status: .lobby,
            isLeader: false
        )
        let fakeStorage = FakeActiveTripStorage(initial: sampleDraft)
        let viewModel = HomeViewModel(mapService: mockMap, searchService: mockSearch, activeTripStorage: fakeStorage)

        #expect(viewModel.activeDraftTrip != nil)
        await viewModel.continueDraftTrip(tripService: service)

        #expect(viewModel.activeDraftTrip == nil)
        #expect(viewModel.activeTripSession == nil)
        #expect(viewModel.activeMapSession == nil)
        #expect(fakeStorage.storedSummary == nil)
        #expect(viewModel.lastTripEndedNotice == "Your last trip has ended.")
    }

    @Test("continueDraftTrip keeps the draft and says so when the trip cannot be loaded")
    func continueDraftTripCannotLoad() async {
        let service = SampleTrip.Service(status: .inTrip, me: SampleTrip.agusID)
        service.simulatedFailure = .noNetwork
        let sampleDraft = ActiveTripSummary(
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            roomCode: SampleTrip.roomCode,
            startName: "Start",
            destinationName: "End",
            memberNames: ["Agus"],
            status: .lobby,
            isLeader: true
        )
        let fakeStorage = FakeActiveTripStorage(initial: sampleDraft)
        let viewModel = HomeViewModel(
            mapService: MockMapService(),
            searchService: MockLocationSearchService(),
            activeTripStorage: fakeStorage
        )

        await viewModel.continueDraftTrip(tripService: service, retryDelay: .zero)

        // An empty Trip Room without the route or the cars would look like the trip was lost.
        #expect(viewModel.activeTripSession == nil)
        #expect(viewModel.activeMapSession == nil)
        #expect(viewModel.activeDraftTrip == sampleDraft)
        #expect(fakeStorage.storedSummary == sampleDraft)
        #expect(viewModel.draftTripErrorMessage != nil)
    }

    @Test("handleDraftTripEnded clears storage, dismisses draft, and sets error notice")
    func handleDraftTripEnded() {
        let mockMap = MockMapService()
        let mockSearch = MockLocationSearchService()
        let sampleDraft = ActiveTripSummary(
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            roomCode: SampleTrip.roomCode,
            startName: "Start",
            destinationName: "End",
            memberNames: ["Budi"],
            status: .lobby,
            isLeader: false
        )
        let fakeStorage = FakeActiveTripStorage(initial: sampleDraft)
        let viewModel = HomeViewModel(mapService: mockMap, searchService: mockSearch, activeTripStorage: fakeStorage)

        #expect(viewModel.activeDraftTrip != nil)
        viewModel.handleDraftTripEnded()

        #expect(viewModel.activeDraftTrip == nil)
        #expect(fakeStorage.storedSummary == nil)
        #expect(viewModel.lastTripEndedNotice == "Your last trip has ended.")
    }

    @Test("onTripStartedFromRoom transitions from Trip Room to Trip Maps")
    func onTripStartedFromRoom() async throws {
        let mockMap = MockMapService()
        let mockSearch = MockLocationSearchService()
        let fakeStorage = FakeActiveTripStorage()
        let viewModel = HomeViewModel(mapService: mockMap, searchService: mockSearch, activeTripStorage: fakeStorage)
        let sampleTrip = Trip(
            id: UUID(),
            roomCode: "654321",
            status: .lobby,
            leaderParticipantID: UUID(),
            currentWaypointIndex: 0,
            routeVersion: 1,
            createdAt: Date(),
            startedAt: nil,
            endedAt: nil
        )
        let session = TripSession(
            myParticipantID: UUID(),
            state: TripState(trip: sampleTrip, waypoints: [], participants: [], route: nil)
        )

        viewModel.activeTripSession = session
        viewModel.onTripStartedFromRoom(session: session)

        #expect(viewModel.activeTripSession == nil)
        #expect(viewModel.isTransitioningToTripMap == true)
        try await Task.sleep(for: .milliseconds(350))
        #expect(viewModel.activeMapSession?.state.trip.id == session.state.trip.id)
        #expect(viewModel.isTransitioningToTripMap == false)
    }
}
