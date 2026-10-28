//
//  TripMapViewModelAlertTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 28/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The silent formation alerts on the trip map, and the leader moving the trip past a checkpoint
/// (`specs/UserStories.md` → US-06).
struct TripMapViewModelAlertTests {
    private typealias Fixtures = TripMapFixtures

    /// The start of the route, where nobody is off route or ahead of anyone.
    private static let onRoute = Fixtures.startPoint.coordinate
    /// About 150 m north of the start, away from the route.
    private static let offRoute = Coordinate(latitude: onRoute.latitude + 0.00136, longitude: onRoute.longitude)

    private func MakeViewModel(me: UUID = Fixtures.budiID, service: MockTripService) -> TripMapViewModel {
        TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: me,
            tripService: service,
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
            streetNameService: MockStreetNameService(),
            clock: { Fixtures.now }
        )
    }

    /// The trip with Budi at `budi`, his phone's reading `secondsAgo` before now. Agus waits at the start.
    private func State(
        budi: Coordinate = onRoute,
        secondsAgo: Double = 1,
        budiAlert: FormationAlert = .none,
        citraAlert: FormationAlert = .none,
        agus: Coordinate = onRoute,
        currentWaypointIndex: Int = 1
    ) -> TripState {
        var agusCar = Fixtures.Car(id: Fixtures.agusID, name: "Agus")
        agusCar.coordinate = agus
        var budiCar = Fixtures.Car(id: Fixtures.budiID, name: "Budi", lastSeenSecondsAgo: secondsAgo)
        budiCar.coordinate = budi
        budiCar.alert = budiAlert
        var citraCar = Fixtures.Car(id: Fixtures.citraID, name: "Citra")
        citraCar.coordinate = Self.onRoute
        citraCar.alert = citraAlert
        return Fixtures.State(cars: [agusCar, budiCar, citraCar], currentWaypointIndex: currentWaypointIndex)
    }

    /// Budi off the route long enough for the alert, then for `moreReadings` more readings.
    private func BudiOffRoute(moreReadings: Int = 0) -> [TripState] {
        [State(budi: Self.offRoute, secondsAgo: 30), State(budi: Self.offRoute, secondsAgo: 14)]
            + (0..<moreReadings).map { State(budi: Self.offRoute, secondsAgo: 13 - Double($0)) }
    }

    // MARK: My own alert

    @Test func MemberOffTheRouteSeesTheBannerAndSavesTheAlert() async {
        let service = MockTripService(states: BudiOffRoute())
        let viewModel = MakeViewModel(service: service)

        await viewModel.Start()

        #expect(viewModel.alertBanner == .mine(.offRoute))
        #expect(service.savedAlerts == [.offRoute])
    }

    @Test func ShortTimeOffTheRouteShowsNothing() async {
        let service = MockTripService(states: [State(budi: Self.offRoute, secondsAgo: 5)])
        let viewModel = MakeViewModel(service: service)

        await viewModel.Start()

        #expect(viewModel.alertBanner == nil)
        #expect(service.savedAlerts.isEmpty)
    }

    @Test func AlertIsSavedOnceWhileItLasts() async {
        let service = MockTripService(states: BudiOffRoute(moreReadings: 3))
        let viewModel = MakeViewModel(service: service)

        await viewModel.Start()

        #expect(service.savedAlerts == [.offRoute])
    }

    @Test func BackOnTheRouteClearsTheBannerAndTheSavedAlert() async {
        let service = MockTripService(states: BudiOffRoute() + [State(budi: Self.onRoute, secondsAgo: 1)])
        let viewModel = MakeViewModel(service: service)

        await viewModel.Start()

        #expect(viewModel.alertBanner == nil)
        #expect(service.savedAlerts == [.offRoute, .none])
    }

    @Test func FailedSaveIsTriedAgainOnTheNextUpdate() async {
        let service = MockTripService(states: BudiOffRoute(moreReadings: 1))
        service.nextAlertFailure = .noNetwork
        let viewModel = MakeViewModel(service: service)

        await viewModel.Start()

        #expect(viewModel.alertBanner == .mine(.offRoute))
        #expect(service.savedAlerts == [.offRoute])
    }

    @Test func LeaderSavesNoAlert() async {
        let states = [30.0, 14].map { State(secondsAgo: $0, agus: Self.offRoute) }
        let service = MockTripService(states: states)
        let viewModel = MakeViewModel(me: Fixtures.agusID, service: service)

        await viewModel.Start()

        #expect(viewModel.alertBanner == nil)
        #expect(service.savedAlerts.isEmpty)
    }

    // MARK: Other cars' alerts

    @Test func LeaderSeesTheCarThatLeftTheRoute() async throws {
        let service = MockTripService(states: [State(budiAlert: .offRoute)])
        let viewModel = MakeViewModel(me: Fixtures.agusID, service: service)

        await viewModel.Start()

        #expect(viewModel.alertBanner == .otherCar(id: Fixtures.budiID, name: "Budi", alert: .offRoute))
        let budi = try #require(viewModel.carPins.first { $0.id == Fixtures.budiID })
        let citra = try #require(viewModel.carPins.first { $0.id == Fixtures.citraID })
        #expect(budi.isAlerting)
        #expect(citra.isAlerting == false)
    }

    @Test func MemberSeesTheCarAheadOfTheLeader() async {
        let service = MockTripService(states: [State(citraAlert: .aheadOfLeader)])
        let viewModel = MakeViewModel(service: service)

        await viewModel.Start()

        #expect(viewModel.alertBanner == .otherCar(id: Fixtures.citraID, name: "Citra", alert: .aheadOfLeader))
    }

    @Test func PassedCheckpointIsOnlyShownToThatCar() async throws {
        let service = MockTripService(states: [State(citraAlert: .passedCheckpoint)])
        let viewModel = MakeViewModel(service: service)

        await viewModel.Start()

        #expect(viewModel.alertBanner == nil)
        let citra = try #require(viewModel.carPins.first { $0.id == Fixtures.citraID })
        #expect(citra.isAlerting == false)
    }

    @Test func MyAlertComesBeforeOtherCars() async {
        let states = [30.0, 14].map { State(budi: Self.offRoute, secondsAgo: $0, citraAlert: .aheadOfLeader) }
        let viewModel = MakeViewModel(service: MockTripService(states: states))

        await viewModel.Start()

        #expect(viewModel.alertBanner == .mine(.offRoute))
    }

    @Test func OffRouteCarComesBeforeCarAheadOfTheLeader() async {
        let service = MockTripService(states: [State(budiAlert: .offRoute, citraAlert: .aheadOfLeader)])
        let viewModel = MakeViewModel(me: Fixtures.agusID, service: service)

        await viewModel.Start()

        #expect(viewModel.alertBanner == .otherCar(id: Fixtures.budiID, name: "Budi", alert: .offRoute))
    }

    // MARK: Closing the banner

    @Test func ClosedBannerStaysHiddenWhileTheAlertLasts() async {
        let service = MockTripService(states: BudiOffRoute(moreReadings: 2))
        let viewModel = MakeViewModel(service: service)
        service.beforeEachState = { index in
            if index == 2 { viewModel.DismissAlertBanner() }
        }

        await viewModel.Start()

        #expect(viewModel.alertBanner == nil)
    }

    @Test func ClosedBannerComesBackWhenItHappensAgain() async {
        let states = [
            State(budiAlert: .offRoute),
            State(budiAlert: .offRoute),
            State(budiAlert: .none),
            State(budiAlert: .offRoute)
        ]
        let service = MockTripService(states: states)
        let viewModel = MakeViewModel(me: Fixtures.agusID, service: service)
        var bannerAfterClosing: TripMapAlerts.Banner?
        service.beforeEachState = { index in
            if index == 1 { viewModel.DismissAlertBanner() }
            if index == 2 { bannerAfterClosing = viewModel.alertBanner }
        }

        await viewModel.Start()

        #expect(bannerAfterClosing == nil)
        #expect(viewModel.alertBanner == .otherCar(id: Fixtures.budiID, name: "Budi", alert: .offRoute))
    }

    @Test func ClosingWithoutABannerChangesNothing() {
        let viewModel = MakeViewModel(service: MockTripService(states: []))

        viewModel.DismissAlertBanner()

        #expect(viewModel.alertBanner == nil)
    }

    // MARK: Checkpoints follow the leader

    @Test func LeaderAtTheCheckpointMovesTheTripPastIt() async {
        let atCheckpoint = State(agus: Fixtures.checkpoint.coordinate)
        let service = MockTripService(states: [atCheckpoint, atCheckpoint])
        let viewModel = MakeViewModel(me: Fixtures.agusID, service: service)

        await viewModel.Start()

        #expect(service.advancedCheckpointIndexes == [2])
    }

    @Test func LeaderFiftyMetresAwayDoesNotPassTheCheckpoint() async {
        let checkpoint = Fixtures.checkpoint.coordinate
        let nearby = Coordinate(latitude: checkpoint.latitude + 0.00045, longitude: checkpoint.longitude)
        let service = MockTripService(states: [State(agus: nearby)])
        let viewModel = MakeViewModel(me: Fixtures.agusID, service: service)

        await viewModel.Start()

        #expect(service.advancedCheckpointIndexes.isEmpty)
    }

    @Test func MemberAtTheCheckpointDoesNotPassIt() async {
        let service = MockTripService(states: [State(budi: Fixtures.checkpoint.coordinate)])
        let viewModel = MakeViewModel(service: service)

        await viewModel.Start()

        #expect(service.advancedCheckpointIndexes.isEmpty)
    }

    @Test func LeaderAtTheDestinationMovesNothing() async {
        let state = State(agus: Fixtures.destination.coordinate, currentWaypointIndex: 2)
        let service = MockTripService(states: [state])
        let viewModel = MakeViewModel(me: Fixtures.agusID, service: service)

        await viewModel.Start()

        #expect(service.advancedCheckpointIndexes.isEmpty)
    }

    @Test func FailedCheckpointMoveIsTriedAgain() async {
        let atCheckpoint = State(agus: Fixtures.checkpoint.coordinate)
        let service = MockTripService(states: [atCheckpoint, atCheckpoint])
        service.nextAdvanceFailure = .noNetwork
        let viewModel = MakeViewModel(me: Fixtures.agusID, service: service)

        await viewModel.Start()

        #expect(service.advancedCheckpointIndexes == [2])
    }
}
