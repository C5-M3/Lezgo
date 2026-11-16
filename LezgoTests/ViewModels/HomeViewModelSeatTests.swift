//
//  HomeViewModelSeatTests.swift
//  LezgoTests
//
//  Created by Oky Faishal on 16/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// Home and Draft Trip follow the iCloud account's seat, not only what this phone saved (ADR 0031).
@MainActor
struct HomeViewModelSeatTests {
    private let store = InMemoryTripStore()

    private func MakePhone() -> InMemoryTripService {
        InMemoryTripService(store: store, userRecordID: "_agus0001")
    }

    private func MakeViewModel(storage: FakeActiveTripStorage) -> HomeViewModel {
        HomeViewModel(
            mapService: MockMapService(),
            searchService: MockLocationSearchService(),
            activeTripStorage: storage
        )
    }

    private func Summary(of tripID: UUID = UUID(), accountID: String? = nil) -> ActiveTripSummary {
        ActiveTripSummary(
            tripID: tripID,
            myParticipantID: UUID(),
            roomCode: "123456",
            startName: "Start",
            destinationName: "End",
            accountID: accountID
        )
    }

    // MARK: Refresh

    @Test func PhoneWithoutASavedTripFindsTheTripOfTheAccount() async throws {
        let first = MakePhone()
        let session = try await first.CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)
        let storage = FakeActiveTripStorage()
        let viewModel = MakeViewModel(storage: storage)

        await viewModel.RefreshActiveTrip(tripService: MakePhone())

        #expect(viewModel.activeDraftTrip?.tripID == session.state.trip.id)
        #expect(viewModel.activeDraftTrip?.myParticipantID == session.myParticipantID)
        #expect(storage.LoadActiveTrip() == viewModel.activeDraftTrip)
        #expect(viewModel.isDraftTripFromAnotherPhone)
    }

    @Test func PhoneThatSavedTheTripKeepsItsOwnDetails() async throws {
        let first = MakePhone()
        let session = try await first.CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)
        var saved = ActiveTripSummary.From(session: session, distanceText: "12.3 km", estimatedDuration: 900)
        saved.accountID = try await first.AccountID()
        let viewModel = MakeViewModel(storage: FakeActiveTripStorage(initial: saved))

        await viewModel.RefreshActiveTrip(tripService: first)

        #expect(viewModel.activeDraftTrip?.distanceText == "12.3 km")
        #expect(viewModel.activeDraftTrip?.estimatedDuration == 900)
        #expect(viewModel.isDraftTripFromAnotherPhone == false)
    }

    @Test func AccountWithoutATripOpensHomeAndForgetsTheSavedOne() async {
        let storage = FakeActiveTripStorage(initial: Summary())
        let viewModel = MakeViewModel(storage: storage)

        await viewModel.RefreshActiveTrip(tripService: MakePhone())

        #expect(viewModel.activeDraftTrip == nil)
        #expect(storage.LoadActiveTrip() == nil)
    }

    @Test func SavedTripStaysWhenICloudCannotBeReached() async {
        let storage = FakeActiveTripStorage(initial: Summary())
        let viewModel = MakeViewModel(storage: storage)
        let service = MakePhone()
        service.simulatedFailure = .noNetwork

        await viewModel.RefreshActiveTrip(tripService: service)

        #expect(viewModel.activeDraftTrip != nil)
        #expect(storage.LoadActiveTrip() != nil)
    }

    @Test func SavedTripOfAnotherAccountIsDroppedEvenOffline() async {
        let service = MockTripService(states: [])
        service.myTripFailure = .noNetwork
        let storage = FakeActiveTripStorage(initial: Summary(accountID: "someone-else"))
        let viewModel = MakeViewModel(storage: storage)

        await viewModel.RefreshActiveTrip(tripService: service)

        #expect(viewModel.activeDraftTrip == nil)
        #expect(storage.LoadActiveTrip() == nil)
    }

    @Test func SavedTripOfThisAccountStaysOffline() async {
        let service = MockTripService(states: [])
        service.myTripFailure = .noNetwork
        let storage = FakeActiveTripStorage(initial: Summary(accountID: "mock-account"))
        let viewModel = MakeViewModel(storage: storage)

        await viewModel.RefreshActiveTrip(tripService: service)

        #expect(viewModel.activeDraftTrip != nil)
    }

    /// A trip created while the answer was on its way must not be wiped by an answer that was true before it.
    @Test func AnswerThatIsOlderThanThePhonesOwnTripIsIgnored() async {
        let service = MockTripService(states: [])
        let storage = FakeActiveTripStorage()
        let viewModel = MakeViewModel(storage: storage)
        let created = Summary()
        service.whileFindingMyTrip = {
            storage.SaveActiveTrip(created)
            viewModel.activeDraftTrip = created
        }

        await viewModel.RefreshActiveTrip(tripService: service)

        #expect(viewModel.activeDraftTrip == created)
        #expect(storage.LoadActiveTrip() == created)
    }

    @Test func RefreshLeavesAnOpenTripRoomAlone() async throws {
        let first = MakePhone()
        let session = try await first.CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)
        let viewModel = MakeViewModel(storage: FakeActiveTripStorage())
        viewModel.activeTripSession = session

        await viewModel.RefreshActiveTrip(tripService: MakePhone())

        #expect(viewModel.activeDraftTrip == nil)
    }

    // MARK: Continue

    @Test func ContinueResumesTheTripSoThisPhoneHoldsTheSeat() async throws {
        let service = MockTripService(states: [TripMapFixtures.State()])
        let draft = Summary(tripID: TripMapFixtures.tripID)
        let viewModel = MakeViewModel(storage: FakeActiveTripStorage(initial: draft))

        await viewModel.continueDraftTrip(tripService: service)

        #expect(service.resumedTripIDs == [TripMapFixtures.tripID])
    }

    @Test(arguments: [TripServiceError.notFound, .tripEnded])
    func ContinueAfterTheTripIsGoneShowsTheTripEnded(error: TripServiceError) async {
        let service = MockTripService(states: [])
        service.resumeFailure = error
        let storage = FakeActiveTripStorage(initial: Summary())
        let viewModel = MakeViewModel(storage: storage)

        await viewModel.continueDraftTrip(tripService: service)

        #expect(viewModel.activeDraftTrip == nil)
        #expect(viewModel.lastTripEndedNotice != nil)
        #expect(storage.LoadActiveTrip() == nil)
    }

    @Test func ContinueFromAnotherPhoneAsksFirst() {
        let viewModel = MakeViewModel(storage: FakeActiveTripStorage(initial: Summary()))
        viewModel.isDraftTripFromAnotherPhone = true

        viewModel.RequestContinue()

        #expect(viewModel.isConfirmingContinue)
    }

    @Test func ContinueOnThePhoneThatSavedTheTripDoesNotAsk() {
        let viewModel = MakeViewModel(storage: FakeActiveTripStorage(initial: Summary()))

        viewModel.RequestContinue()

        #expect(viewModel.isConfirmingContinue == false)
    }
}
