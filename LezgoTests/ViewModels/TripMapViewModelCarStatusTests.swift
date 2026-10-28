//
//  TripMapViewModelCarStatusTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 28/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The car status card on the trip map (`specs/UserStories.md` → US-06, "Car status"). Agus, the leader, uses
/// this phone and taps the other cars.
struct TripMapViewModelCarStatusTests {
    private typealias Fixtures = TripMapFixtures

    private func MakeViewModel(
        states: [TripState] = [Fixtures.State()],
        navigator: MockTripMapNavigator = MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
        streetNames: MockStreetNameService = MockStreetNameService(),
        clock: @escaping () -> Date = { Fixtures.now }
    ) -> TripMapViewModel {
        TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: Fixtures.agusID,
            tripService: MockTripService(states: states),
            navigator: navigator,
            streetNameService: streetNames,
            clock: clock
        )
    }

    private func Coordinate(of carID: UUID) throws -> Lezgo.Coordinate {
        try #require(Fixtures.State().participants.first { $0.id == carID }?.coordinate)
    }

    /// Agus's car, and a stopped or offline Budi.
    private func StateWithBudi(motionState: MotionState = .driving, lastSeenSecondsAgo: Double = 1) -> TripState {
        Fixtures.State(cars: [
            Fixtures.Car(id: Fixtures.agusID, name: "Agus", latitude: -7.2650),
            Fixtures.Car(
                id: Fixtures.budiID,
                name: "Budi",
                latitude: -7.2700,
                lastSeenSecondsAgo: lastSeenSecondsAgo,
                motionState: motionState
            )
        ])
    }

    // MARK: Opening the card

    @Test func NoCardUntilACarIsTapped() async {
        let viewModel = MakeViewModel()

        await viewModel.Start()

        #expect(viewModel.selectedCarID == nil)
        #expect(viewModel.selectedCarStatus == nil)
    }

    /// Scenario "Tap a car": Budi drives on Ahmad Yani Street, 50 minutes from the destination.
    @Test func TappingACarShowsItsDriverStreetAndTimeLeft() async throws {
        let navigator = MockTripMapNavigator(results: [.success(Fixtures.Guidance(minutesLeft: 50))])
        let viewModel = MakeViewModel(navigator: navigator)
        await viewModel.Start()

        viewModel.SelectCar(Fixtures.budiID)
        await viewModel.RefreshSelectedCarStatus()

        let status = try #require(viewModel.selectedCarStatus)
        #expect(status.id == Fixtures.budiID)
        #expect(status.displayName == "Budi")
        #expect(status.statusLine == "Driving at Ahmad Yani Street")
        #expect(status.timeLeft == .seconds(50 * 60))
    }

    @Test func StreetAndTimeLeftAreMeasuredFromTheTappedCar() async throws {
        let navigator = MockTripMapNavigator(results: [.success(Fixtures.Guidance())])
        let streetNames = MockStreetNameService()
        let viewModel = MakeViewModel(navigator: navigator, streetNames: streetNames)
        await viewModel.Start()

        viewModel.SelectCar(Fixtures.budiID)
        await viewModel.RefreshSelectedCarStatus()

        let budi = try Coordinate(of: Fixtures.budiID)
        #expect(streetNames.requestedCoordinates == [budi])
        #expect(navigator.requestedPositions.last == budi)
    }

    @Test func StoppedCarSaysWhereItStopped() async throws {
        let viewModel = MakeViewModel(states: [StateWithBudi(motionState: .stopped)])
        await viewModel.Start()

        viewModel.SelectCar(Fixtures.budiID)
        await viewModel.RefreshSelectedCarStatus()

        #expect(viewModel.selectedCarStatus?.statusLine == "Stopped at Ahmad Yani Street")
    }

    @Test func OfflineCarShowsWhenItWasLastSeenWithoutLookingItUp() async throws {
        let navigator = MockTripMapNavigator(results: [.success(Fixtures.Guidance())])
        let streetNames = MockStreetNameService()
        let viewModel = MakeViewModel(
            states: [StateWithBudi(lastSeenSecondsAgo: 180)],
            navigator: navigator,
            streetNames: streetNames
        )
        await viewModel.Start()

        viewModel.SelectCar(Fixtures.budiID)
        await viewModel.RefreshSelectedCarStatus()

        let status = try #require(viewModel.selectedCarStatus)
        #expect(status.statusLine == "Last seen 3 min ago")
        #expect(status.timeLeft == nil)
        #expect(streetNames.requestedCoordinates.isEmpty)
        let budi = try Coordinate(of: Fixtures.budiID)
        #expect(navigator.requestedPositions.contains(budi) == false)
    }

    @Test func CardShowsTheStatusAloneUntilTheLookupReturns() async throws {
        let viewModel = MakeViewModel()
        await viewModel.Start()

        viewModel.SelectCar(Fixtures.budiID)

        let status = try #require(viewModel.selectedCarStatus)
        #expect(status.statusLine == "Driving")
        #expect(status.timeLeft == nil)
    }

    /// No network, or a place the map has no name for: the card still opens, with what is known.
    @Test(arguments: [
        Result<String?, MockStreetNameService.LookupFailed>.failure(.init()),
        .success(nil)
    ])
    func CardWithoutAStreetShowsTheStatusAlone(street: Result<String?, MockStreetNameService.LookupFailed>) async {
        let viewModel = MakeViewModel(streetNames: MockStreetNameService(results: [street]))
        await viewModel.Start()

        viewModel.SelectCar(Fixtures.budiID)
        await viewModel.RefreshSelectedCarStatus()

        #expect(viewModel.selectedCarStatus?.statusLine == "Driving")
    }

    @Test func CardWithoutRoutingShowsNoTimeLeft() async throws {
        let navigator = MockTripMapNavigator(results: [.failure(.init())])
        let viewModel = MakeViewModel(navigator: navigator)
        await viewModel.Start()

        viewModel.SelectCar(Fixtures.budiID)
        await viewModel.RefreshSelectedCarStatus()

        let status = try #require(viewModel.selectedCarStatus)
        #expect(status.statusLine == "Driving at Ahmad Yani Street")
        #expect(status.timeLeft == nil)
    }

    // MARK: Looking up at most every 30 seconds

    @Test(arguments: [(10.0, 1), (29.0, 1), (30.0, 2), (45.0, 2)])
    func StreetAndTimeLeftAreLookedUpAtMostEvery30Seconds(secondsLater: Double, lookups: Int) async throws {
        var now = Fixtures.now
        let navigator = MockTripMapNavigator(results: [.success(Fixtures.Guidance())])
        let streetNames = MockStreetNameService()
        let viewModel = MakeViewModel(navigator: navigator, streetNames: streetNames, clock: { now })
        await viewModel.Start()
        viewModel.SelectCar(Fixtures.budiID)
        await viewModel.RefreshSelectedCarStatus()

        now += secondsLater
        await viewModel.RefreshSelectedCarStatus()

        let budi = try Coordinate(of: Fixtures.budiID)
        #expect(streetNames.requestedCoordinates.count == lookups)
        #expect(navigator.requestedPositions.filter { $0 == budi }.count == lookups)
    }

    @Test func FailedLookupKeepsTheLastStreetAndTimeLeft() async throws {
        var now = Fixtures.now
        // The first answer is the guidance for my own car, when the trip update arrives.
        let navigator = MockTripMapNavigator(results: [
            .success(Fixtures.Guidance()),
            .success(Fixtures.Guidance(minutesLeft: 50)),
            .failure(.init())
        ])
        let streetNames = MockStreetNameService(results: [.success("Ahmad Yani Street"), .failure(.init())])
        let viewModel = MakeViewModel(navigator: navigator, streetNames: streetNames, clock: { now })
        await viewModel.Start()
        viewModel.SelectCar(Fixtures.budiID)
        await viewModel.RefreshSelectedCarStatus()

        now += 31
        await viewModel.RefreshSelectedCarStatus()

        let status = try #require(viewModel.selectedCarStatus)
        #expect(streetNames.requestedCoordinates.count == 2)
        #expect(status.statusLine == "Driving at Ahmad Yani Street")
        #expect(status.timeLeft == .seconds(50 * 60))
    }

    @Test func EachCarKeepsItsOwnStreet() async {
        let streetNames = MockStreetNameService(results: [.success("Ahmad Yani Street"), .success("Jalan Tunjungan")])
        let viewModel = MakeViewModel(streetNames: streetNames)
        await viewModel.Start()

        viewModel.SelectCar(Fixtures.budiID)
        await viewModel.RefreshSelectedCarStatus()
        viewModel.SelectCar(Fixtures.citraID)
        await viewModel.RefreshSelectedCarStatus()
        #expect(viewModel.selectedCarStatus?.statusLine == "Driving at Jalan Tunjungan")

        viewModel.SelectCar(Fixtures.budiID)
        await viewModel.RefreshSelectedCarStatus()
        #expect(viewModel.selectedCarStatus?.statusLine == "Driving at Ahmad Yani Street")
        #expect(streetNames.requestedCoordinates.count == 2)
    }

    /// Tapping Citra while Budi's lookup is still on its way cancels Budi's. Tapping Budi again soon after must look
    /// him up again, not wait 30 seconds with an empty card.
    @Test func CancelledLookupDoesNotDelayTheNextOne() async throws {
        let streetNames = MockStreetNameService(results: [.failure(.init()), .success("Ahmad Yani Street")])
        let viewModel = MakeViewModel(streetNames: streetNames)
        await viewModel.Start()
        viewModel.SelectCar(Fixtures.budiID)

        let cancelledLookup = Task { await viewModel.RefreshSelectedCarStatus() }
        cancelledLookup.cancel()
        await cancelledLookup.value
        await viewModel.RefreshSelectedCarStatus()

        #expect(streetNames.requestedCoordinates.count == 2)
        #expect(viewModel.selectedCarStatus?.statusLine == "Driving at Ahmad Yani Street")
    }

    /// The view starts tracking whenever the tapped car changes, also when the card closes. With no card open there
    /// is nothing to look up, so tracking ends at once instead of waking every 30 seconds.
    @Test(.timeLimit(.minutes(1)))
    func TrackingEndsAtOnceWithoutATappedCar() async {
        let streetNames = MockStreetNameService()
        let viewModel = MakeViewModel(streetNames: streetNames)
        await viewModel.Start()

        await viewModel.TrackSelectedCar()

        #expect(streetNames.requestedCoordinates.isEmpty)
    }

    // MARK: Closing the card

    @Test func TappingElsewhereClosesTheCard() async {
        let viewModel = MakeViewModel()
        await viewModel.Start()
        viewModel.SelectCar(Fixtures.budiID)

        viewModel.SelectCar(nil)

        #expect(viewModel.selectedCarID == nil)
        #expect(viewModel.selectedCarStatus == nil)
    }

    @Test func TappingTheSameCarTwiceKeepsItsCardOpen() async {
        let viewModel = MakeViewModel()
        await viewModel.Start()

        viewModel.SelectCar(Fixtures.budiID)
        viewModel.SelectCar(Fixtures.budiID)

        #expect(viewModel.selectedCarStatus?.id == Fixtures.budiID)
    }

    @Test func CardClosesWhenTheCarLeavesTheTrip() async {
        let withoutBudi = Fixtures.State(cars: [
            Fixtures.Car(id: Fixtures.agusID, name: "Agus", latitude: -7.2650),
            Fixtures.Car(id: Fixtures.citraID, name: "Citra", latitude: -7.2750)
        ])
        let viewModel = MakeViewModel(states: [Fixtures.State(), withoutBudi])
        viewModel.SelectCar(Fixtures.budiID)
        viewModel.FollowSelectedCar()

        await viewModel.Start()

        #expect(viewModel.selectedCarID == nil)
        #expect(viewModel.selectedCarStatus == nil)
        #expect(viewModel.cameraMode == .followMyCar)
    }
}
