//
//  TripMapViewModelShortcutTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 09/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// A member behind a leader who drove a loop is not sent round it: a shorter road to the footprint near the leader
/// is taken instead (`specs/UserStories.md` → US-06, "Footprint").
struct TripMapViewModelShortcutTests {
    private typealias Fixtures = TripMapFixtures
    private static let origin = Coordinate(latitude: -7.2700, longitude: 112.7300)

    /// A point `east` and `north` metres from the origin.
    private static func Point(east: Double, north: Double) -> Coordinate {
        let metresPerDegreeEast = 111_320 * cos(origin.latitude * .pi / 180)
        return Coordinate(
            latitude: origin.latitude + north / 111_320,
            longitude: origin.longitude + east / metresPerDegreeEast
        )
    }

    /// Agus drove south 400 m, west 300 m, then north 450 m: a loop around a block. Budi is at its start, heading south.
    private static let loop = [
        Point(east: 0, north: 400), Point(east: 0, north: 0), Point(east: -300, north: 0), Point(east: -300, north: 400)
    ]
    private static let agusAt = Point(east: -300, north: 450)
    private static let budiAtLoopStart = Point(east: 0, north: 380)

    /// Streets in a grid: a road goes north or south first, then east or west.
    private static func GridRoad(_ points: [Coordinate]) -> [Coordinate]? {
        guard let start = points.first, let end = points.last else { return nil }
        return [start, Coordinate(latitude: end.latitude, longitude: start.longitude), end]
    }

    private func Trip(budi: Coordinate, budiSecondsAgo: Double = 1, trail: [Coordinate] = loop) -> TripState {
        var agus = Fixtures.Car(id: Fixtures.agusID, name: "Agus")
        agus.coordinate = Self.agusAt
        var budiCar = Fixtures.Car(id: Fixtures.budiID, name: "Budi", lastSeenSecondsAgo: budiSecondsAgo)
        budiCar.coordinate = budi
        budiCar.course = 180
        var state = Fixtures.State(cars: [agus, budiCar])
        state.route?.polyline = [Self.agusAt, Self.Point(east: -300, north: 2_000)]
        state.trail = trail
        return state
    }

    private func OpenMap(_ states: [TripState], directions: MockDirectionsService) async -> TripMapViewModel {
        let viewModel = TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: Fixtures.budiID,
            tripService: MockTripService(states: states),
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
            streetNameService: MockStreetNameService(),
            directionsService: directions,
            clock: { Fixtures.now }
        )
        await viewModel.Start()
        return viewModel
    }

    private func GridDirections() -> MockDirectionsService {
        let directions = MockDirectionsService(results: [])
        directions.roads = Self.GridRoad
        return directions
    }

    @Test func MemberAtTheStartOfTheLeadersLoopTakesTheSideRoad() async throws {
        let viewModel = await OpenMap([Trip(budi: Self.budiAtLoopStart)], directions: GridDirections())

        // West along the side road to the last leg of the loop, near Agus, instead of 1.1 km round the block.
        let end = try #require(viewModel.myWayBack.last)
        #expect(abs(end.longitude - Self.Point(east: -300, north: 0).longitude) < 0.000_01)
        #expect(end.latitude > Self.Point(east: 0, north: 300).latitude)
        // Not Agus himself: that road starts by turning back north, against Budi's heading.
        #expect(end.latitude < Self.Point(east: 0, north: 440).latitude)
        #expect(viewModel.isRerouting == false)
    }

    @Test func LeaderIsOneOfThePlacesToJoin() async {
        let directions = GridDirections()

        _ = await OpenMap([Trip(budi: Self.budiAtLoopStart)], directions: directions)

        #expect(directions.requestedPoints.contains { $0.last == Self.agusAt })
        #expect(directions.requestedPoints.count <= 4)
    }

    @Test func MemberOnTheSideRoadIsNotOutOfTheWay() async {
        let viewModel = await OpenMap(
            [
                Trip(budi: Self.budiAtLoopStart, budiSecondsAgo: 20),
                Trip(budi: Self.Point(east: -150, north: 380), budiSecondsAgo: 10),
                Trip(budi: Self.Point(east: -150, north: 380), budiSecondsAgo: 1)
            ],
            directions: GridDirections()
        )

        #expect(viewModel.alertBanner == nil)
        #expect(viewModel.myWayBack.isEmpty == false)
    }

    @Test func NoSideRoadIsAskedForOnAStraightFootprint() async {
        // Agus drove straight north; Budi is 300 m behind him on the same road.
        let directions = GridDirections()
        let straight = [Self.Point(east: -300, north: 0), Self.Point(east: -300, north: 400)]

        _ = await OpenMap([Trip(budi: Self.Point(east: -300, north: 150), trail: straight)], directions: directions)

        #expect(directions.requestedPoints.isEmpty)
    }
}
