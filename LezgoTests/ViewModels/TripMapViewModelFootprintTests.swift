//
//  TripMapViewModelFootprintTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 31/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The leader's footprint on the map (`specs/UserStories.md` → US-06, "Footprint"): the leader's phone records and
/// shares it, members follow it, a member off it is guided back to it, and the leader sees it behind them.
struct TripMapViewModelFootprintTests {
    private typealias Fixtures = TripMapFixtures
    /// About 1 m of latitude or, near Surabaya, of longitude.
    private static let metre = 1 / 111_320.0

    /// Where Budi starts: the footprint runs 200 m north from here, then 200 m east to Agus, who was rerouted there.
    private static let corner = Coordinate(latitude: -7.2700, longitude: 112.7300)
    private static let north = Coordinate(latitude: corner.latitude + 200 * metre, longitude: corner.longitude)
    private static let agusAt = Coordinate(latitude: north.latitude, longitude: north.longitude + 200 * metre)

    /// 100 m up the footprint's first street and 300 m west of it.
    private static let lostAt = Coordinate(
        latitude: corner.latitude + 100 * metre,
        longitude: corner.longitude - 300 * metre
    )

    /// The rerouted trip: the route starts at Agus, and his footprint leads to him from the corner.
    private func Rerouted(budi: Coordinate, budiSecondsAgo: Double = 1) -> TripState {
        var agus = Fixtures.Car(id: Fixtures.agusID, name: "Agus")
        agus.coordinate = Self.agusAt
        var budiCar = Fixtures.Car(id: Fixtures.budiID, name: "Budi", lastSeenSecondsAgo: budiSecondsAgo)
        budiCar.coordinate = budi
        var state = Fixtures.State(cars: [agus, budiCar])
        state.route?.polyline = [Self.agusAt, Fixtures.destination.coordinate]
        state.trail = [Self.corner, Self.north]
        return state
    }

    private func OpenMap(
        _ states: [TripState],
        me: UUID = Fixtures.budiID,
        directions: MockDirectionsService = MockDirectionsService(results: [])
    ) async -> TripMapViewModel {
        let viewModel = TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: me,
            tripService: MockTripService(states: states),
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
            streetNameService: MockStreetNameService(),
            directionsService: directions,
            clock: { Fixtures.now }
        )
        await viewModel.Start()
        return viewModel
    }

    // MARK: Members follow the footprint

    @Test func MemberBehindTheLeaderFollowsTheFootprint() async {
        let budi = Coordinate(latitude: Self.corner.latitude + 20 * Self.metre, longitude: Self.corner.longitude)

        let viewModel = await OpenMap([Rerouted(budi: budi)])

        // From Budi up the footprint to Agus, then on along the route.
        #expect(viewModel.routeAhead.contains(Self.north))
        #expect(viewModel.routeAhead.contains(Self.agusAt))
        #expect(viewModel.routeAhead.last == Fixtures.destination.coordinate)
    }

    @Test func TurnCardFollowsTheFootprint() async throws {
        // Heading north, the footprint turns east towards Agus: a right turn 180 m ahead. MapKit's own route
        // would know nothing about the road Agus took.
        let budi = Coordinate(latitude: Self.corner.latitude + 20 * Self.metre, longitude: Self.corner.longitude)

        let viewModel = await OpenMap([Rerouted(budi: budi)])

        let guidance = try #require(viewModel.guidance)
        #expect(guidance.direction == .right)
        #expect(abs(guidance.distanceToTurn.converted(to: .meters).value - 180) < 5)
        // The time left still comes from the navigator.
        #expect(guidance.timeLeft == Fixtures.Guidance().timeLeft)
    }

    // MARK: Back to the footprint

    @Test func MemberOffTheFootprintIsGuidedBackToIt() async {
        // 300 m west of the footprint for more than 5 seconds.
        let lost = Self.lostAt
        let wayBack = [lost, Coordinate(latitude: lost.latitude, longitude: Self.corner.longitude)]
        let directions = MockDirectionsService(results: [.success(wayBack)])

        let viewModel = await OpenMap(
            [Rerouted(budi: lost, budiSecondsAgo: 10), Rerouted(budi: lost, budiSecondsAgo: 4)],
            directions: directions
        )

        #expect(directions.requestedPoints.first?.first == lost)
        #expect(viewModel.routeAhead.first == lost)
        #expect(viewModel.routeAhead.contains(Self.agusAt))
        // The way back is found, so the turn card shows it instead of "Rerouting…".
        #expect(viewModel.isRerouting == false)
    }

    @Test func WayBackLeadsOnTowardsTheLeaderNotBack() async {
        // Budi drove 120 m up the footprint, then turned off west. The nearest point of the footprint is behind
        // where he left it; the way back goes to the next point ahead of it instead, towards Agus.
        let leftAt = Coordinate(latitude: Self.corner.latitude + 120 * Self.metre, longitude: Self.corner.longitude)
        let lost = Coordinate(latitude: leftAt.latitude, longitude: leftAt.longitude - 300 * Self.metre)
        let directions = MockDirectionsService(results: [.success([lost, Self.north])])

        _ = await OpenMap(
            [
                Rerouted(budi: leftAt, budiSecondsAgo: 20),
                Rerouted(budi: lost, budiSecondsAgo: 12),
                Rerouted(budi: lost, budiSecondsAgo: 4)
            ],
            directions: directions
        )

        #expect(directions.requestedPoints.first == [lost, Self.north])
    }

    @Test func MemberOffTheFootprintSeesReroutingWhileTheWayBackIsFound() async {
        // Three seconds off: too soon to ask MapKit, but the driver already sees the app is working on it.
        let directions = MockDirectionsService(results: [])

        let viewModel = await OpenMap(
            [Rerouted(budi: Self.lostAt, budiSecondsAgo: 5), Rerouted(budi: Self.lostAt, budiSecondsAgo: 2)],
            directions: directions
        )

        #expect(viewModel.isRerouting)
        #expect(directions.requestedPoints.isEmpty)
    }

    @Test func ShortTripOffTheFootprintAsksForNothing() async {
        // A GPS jump of a few seconds is not a wrong turn.
        let lost = Self.lostAt
        let directions = MockDirectionsService(results: [])

        _ = await OpenMap(
            [Rerouted(budi: lost, budiSecondsAgo: 4), Rerouted(budi: lost, budiSecondsAgo: 2)],
            directions: directions
        )

        #expect(directions.requestedPoints.isEmpty)
    }

    // MARK: The leader sees the footprint

    @Test func LeaderSeesTheFootprintBehindThem() async {
        let viewModel = await OpenMap([Rerouted(budi: Self.corner)], me: Fixtures.agusID)

        #expect(viewModel.footprint == [Self.corner, Self.north, Self.agusAt])
    }

    @Test func MembersDoNotDrawTheFootprintBehindThem() async {
        let viewModel = await OpenMap([Rerouted(budi: Self.corner)])

        #expect(viewModel.footprint.isEmpty)
    }
}

/// A member's way back reaches the leader's map, so the leader sees where a car that left the road is being sent.
struct TripMapViewModelMemberWayBackTests {
    private typealias Fixtures = TripMapFixtures
    private static let metre = 1 / 111_320.0
    private static let corner = Coordinate(latitude: -7.2700, longitude: 112.7300)
    private static let lost = Coordinate(latitude: corner.latitude, longitude: corner.longitude - 300 * metre)
    private static let wayBack = [lost, corner]

    /// Agus leads along a route from the corner; Budi is at `budi`.
    private func Trip(budi: Coordinate, secondsAgo: Double = 1, budiWayBack: [Coordinate] = []) -> TripState {
        var agus = Fixtures.Car(id: Fixtures.agusID, name: "Agus")
        agus.coordinate = Self.corner
        var budiCar = Fixtures.Car(id: Fixtures.budiID, name: "Budi", lastSeenSecondsAgo: secondsAgo)
        budiCar.coordinate = budi
        budiCar.wayBack = budiWayBack
        var state = Fixtures.State(cars: [agus, budiCar])
        state.route?.polyline = [Self.corner, Fixtures.destination.coordinate]
        return state
    }

    private func OpenMap(_ service: MockTripService, me: UUID) async -> TripMapViewModel {
        let viewModel = TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: me,
            tripService: service,
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
            streetNameService: MockStreetNameService(),
            directionsService: MockDirectionsService(results: [.success(Self.wayBack)]),
            clock: { Fixtures.now }
        )
        await viewModel.Start()
        return viewModel
    }

    @Test func MembersPhoneSharesItsWayBack() async {
        let service = MockTripService(states: [
            Trip(budi: Self.lost, secondsAgo: 10),
            Trip(budi: Self.lost, secondsAgo: 4)
        ])

        _ = await OpenMap(service, me: Fixtures.budiID)

        #expect(service.savedWayBacks == [Self.wayBack])
    }

    @Test func BackOnTheRoadClearsTheSharedWayBack() async {
        let service = MockTripService(states: [
            Trip(budi: Self.lost, secondsAgo: 10),
            Trip(budi: Self.lost, secondsAgo: 4),
            Trip(budi: Self.corner, secondsAgo: 1)
        ])

        _ = await OpenMap(service, me: Fixtures.budiID)

        #expect(service.savedWayBacks == [Self.wayBack, []])
    }

    @Test func FailedShareIsTriedAgainWithTheNextUpdate() async {
        let service = MockTripService(states: [
            Trip(budi: Self.lost, secondsAgo: 10),
            Trip(budi: Self.lost, secondsAgo: 4),
            Trip(budi: Self.lost, secondsAgo: 3)
        ])
        service.nextWayBackFailure = .noNetwork

        _ = await OpenMap(service, me: Fixtures.budiID)

        #expect(service.savedWayBacks == [Self.wayBack])
    }

    @Test func LeftoverWayBackFromBeforeARestartIsCleared() async {
        // The app was closed on a way back; the car is on the road again when it opens.
        let service = MockTripService(states: [Trip(budi: Self.corner, budiWayBack: Self.wayBack)])

        _ = await OpenMap(service, me: Fixtures.budiID)

        #expect(service.savedWayBacks == [[]])
    }

    @Test func LeaderSeesWhatIsLeftOfAMembersWayBack() async {
        // Budi has driven half of it, so the part behind him is no longer drawn.
        let halfway = Coordinate(latitude: Self.corner.latitude, longitude: Self.corner.longitude - 150 * Self.metre)
        let service = MockTripService(states: [Trip(budi: halfway, budiWayBack: Self.wayBack)])

        let viewModel = await OpenMap(service, me: Fixtures.agusID)

        #expect(viewModel.memberWayBacks.map(\.id) == [Fixtures.budiID])
        #expect(viewModel.memberWayBacks.first?.path.count == 2)
        #expect(viewModel.memberWayBacks.first?.path.last == Self.corner)
        #expect(viewModel.memberWayBacks.first?.path.contains(Self.lost) == false)
        #expect(service.savedWayBacks.isEmpty)
    }

    @Test func OfflineMembersWayBackIsNotDrawn() async {
        // Their last position is out of date, so where they are being sent is too.
        let service = MockTripService(states: [Trip(budi: Self.lost, secondsAgo: 300, budiWayBack: Self.wayBack)])

        let viewModel = await OpenMap(service, me: Fixtures.agusID)

        #expect(viewModel.memberWayBacks.isEmpty)
    }

    @Test func MembersDoNotSeeEachOthersWayBack() async {
        var state = Trip(budi: Self.corner)
        var citra = Fixtures.Car(id: Fixtures.citraID, name: "Citra")
        citra.coordinate = Self.lost
        citra.wayBack = Self.wayBack
        state.participants.append(citra)

        let viewModel = await OpenMap(MockTripService(states: [state]), me: Fixtures.budiID)

        #expect(viewModel.memberWayBacks.isEmpty)
    }
}

/// The leader's phone records where the leader drives and shares it with the group.
struct TripMapViewModelFootprintRecordingTests {
    private static let metre = 1 / 111_320.0

    @Test func LeadersDriveIsSaved() async throws {
        let service = SampleTrip.Service(status: .inTrip, me: SampleTrip.agusID)
        let gps = MockLocationProvider()
        let viewModel = TripMapViewModel(
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            tripService: service,
            navigator: MockTripMapNavigator(results: [.success(TripMapFixtures.Guidance())]),
            streetNameService: MockStreetNameService(),
            locationSharer: LocationSharer(
                tripService: service,
                locationProvider: gps,
                tripID: SampleTrip.tripID,
                participantID: SampleTrip.agusID,
                interval: .milliseconds(10)
            )
        )
        let open = Task { await viewModel.Start() }
        for _ in 0..<200 where viewModel.state == nil {
            try await Task.sleep(for: .milliseconds(10))
        }

        // Three positions 30 m apart, 6 seconds apart: each one is saved.
        let start = Coordinate(latitude: -7.27, longitude: 112.73)
        let now = Date.now
        for step in 0..<3 {
            let point = Coordinate(
                latitude: start.latitude + Double(step) * 30 * Self.metre,
                longitude: start.longitude
            )
            let recordedAt = now.addingTimeInterval(Double(step) * 6)
            gps.Send(LocationReading(coordinate: point, speedKmh: 30, recordedAt: recordedAt))
            for _ in 0..<200 where (try? await service.FetchTrip(tripID: SampleTrip.tripID).trail.count) != step + 1 {
                try await Task.sleep(for: .milliseconds(10))
            }
        }
        let saved = try await service.FetchTrip(tripID: SampleTrip.tripID).trail
        open.cancel()
        await open.value

        #expect(saved.count == 3)
        #expect(saved.first == start)
    }
}
