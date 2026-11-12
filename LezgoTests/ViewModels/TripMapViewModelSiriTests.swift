//
//  TripMapViewModelSiriTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// What the trip map gives Siri (`specs/UserStories.md` → US-08): the answers, a car's street and time left, the
/// mute switch and "I've Arrived".
struct TripMapViewModelSiriTests {
    private typealias Fixtures = TripMapFixtures

    /// Each test gets its own preferences, so a mute saved by one test never reaches another.
    private let preferences: UserDefaults

    init() throws {
        preferences = try #require(UserDefaults(suiteName: "TripMapViewModelSiriTests.\(UUID().uuidString)"))
    }

    private func MakeViewModel(
        state: TripState = Fixtures.State(),
        service: MockTripService? = nil,
        streets: MockStreetNameService = MockStreetNameService(),
        navigator: MockTripMapNavigator = MockTripMapNavigator(results: [.success(Fixtures.Guidance())])
    ) -> (TripMapViewModel, MockTripService) {
        let service = service ?? MockTripService(states: [state])
        let viewModel = TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: Fixtures.budiID,
            tripService: service,
            navigator: navigator,
            streetNameService: streets,
            clock: { Fixtures.now }
        )
        viewModel.sound = TripMapSound(preferences: preferences)
        return (viewModel, service)
    }

    // MARK: Answers

    @Test func BeforeTheTripLoadsThereAreNoAnswers() {
        let (viewModel, _) = MakeViewModel()

        #expect(viewModel.SiriAnswers() == nil)
    }

    @Test func AnswersUseWhatTheMapShows() async throws {
        let (viewModel, _) = MakeViewModel()
        await viewModel.Start()

        let answers = try #require(viewModel.SiriAnswers())

        #expect(answers.state == viewModel.state)
        #expect(answers.myParticipantID == Fixtures.budiID)
        #expect(answers.myCoordinate == viewModel.myCoordinate)
        #expect(answers.guidance == Fixtures.Guidance())
        #expect(answers.now == Fixtures.now)
    }

    @Test func AClosedMapHasNoAnswers() async {
        var ended = Fixtures.State()
        ended.trip.status = .ended
        let (viewModel, _) = MakeViewModel(service: MockTripService(states: [Fixtures.State(), ended]))
        await viewModel.Start()

        #expect(viewModel.SiriAnswers() == nil)
    }

    // MARK: Looking up a car

    @Test func LookingUpACarGivesItsStreetToTheAnswers() async throws {
        let (viewModel, _) = MakeViewModel()
        await viewModel.Start()

        await viewModel.LookUpCar(Fixtures.agusID)

        let answers = try #require(viewModel.SiriAnswers())
        #expect(answers.streets[Fixtures.agusID] == "Ahmad Yani Street")
        #expect(viewModel.carLookups[Fixtures.agusID]?.timeLeft == Fixtures.Guidance().timeLeft)
    }

    @Test func ACarLookedUpRecentlyIsNotLookedUpAgain() async {
        let streets = MockStreetNameService()
        let (viewModel, _) = MakeViewModel(streets: streets)
        await viewModel.Start()

        await viewModel.LookUpCar(Fixtures.agusID)
        await viewModel.LookUpCar(Fixtures.agusID)

        #expect(streets.requestedCoordinates.count == 1)
    }

    @Test func AnOfflineCarIsNotLookedUp() async {
        var state = Fixtures.State()
        state.participants[0].lastSeenAt = Fixtures.now.addingTimeInterval(-300)
        let streets = MockStreetNameService()
        let (viewModel, _) = MakeViewModel(state: state, streets: streets)
        await viewModel.Start()

        await viewModel.LookUpCar(Fixtures.agusID)

        #expect(streets.requestedCoordinates.isEmpty)
    }

    // MARK: Mute

    @Test func MuteBySiriMutesTheMap() {
        let (viewModel, _) = MakeViewModel()

        viewModel.SetMuted(true)

        #expect(viewModel.sound.isMuted)
    }

    @Test func MutingTwiceStaysMuted() {
        let (viewModel, _) = MakeViewModel()

        viewModel.SetMuted(true)
        viewModel.SetMuted(true)

        #expect(viewModel.sound.isMuted)
    }

    @Test func UnmuteBySiriUnmutesTheMap() {
        let (viewModel, _) = MakeViewModel()
        viewModel.SetMuted(true)

        viewModel.SetMuted(false)

        #expect(viewModel.sound.isMuted == false)
    }

    // MARK: I've arrived

    private func Confirmation() -> TripMapManualArrival.Confirmation {
        TripMapManualArrival.Confirmation(
            destinationID: Fixtures.destination.id,
            destinationName: "Pakuwon mall",
            distance: Measurement(value: 200, unit: .meters)
        )
    }

    @Test func ArrivingBySiriSavesTheArrival() async {
        let (viewModel, service) = MakeViewModel()
        await viewModel.Start()

        let answer = await viewModel.ArriveFromSiri(Confirmation())

        #expect(service.markedArrivals == [Fixtures.destination.id])
        #expect(answer == "You've arrived. Waiting for everyone to arrive.")
    }

    @Test func TheLastCarToArriveHearsEveryoneHasArrived() async {
        var state = Fixtures.State()
        for index in state.participants.indices where state.participants[index].id != Fixtures.budiID {
            state.participants[index].arrivedAtWaypointID = Fixtures.destination.id
        }
        let (viewModel, _) = MakeViewModel(state: state)
        await viewModel.Start()

        let answer = await viewModel.ArriveFromSiri(Confirmation())

        #expect(answer == "Everyone has arrived!")
    }

    @Test func AFailedSaveIsSpokenNotLeftOnTheMap() async {
        let (viewModel, service) = MakeViewModel()
        service.nextMarkArrivedFailure = .noNetwork
        await viewModel.Start()

        let answer = await viewModel.ArriveFromSiri(Confirmation())

        #expect(answer == "Couldn't save your arrival. Check your connection and try again.")
        #expect(viewModel.manualArrival.errorMessage == nil)
    }
}
