//
//  MapViewModelTripCreationTests.swift
//  LezgoTests
//
//  Created by Farrell Sudjatmiko on 30/10/26.
//

import CoreLocation
import MapKit
import Testing
@testable import Lezgo

@MainActor
struct MapViewModelTripCreationTests {
    private typealias Fixtures = TripMapFixtures

    private final class FakeRoute: MKRoute {
        private let line: MKPolyline

        init(through coordinates: [Coordinate]) {
            let points = coordinates.map(\.locationCoordinate)
            line = MKPolyline(coordinates: points, count: points.count)
            super.init()
        }

        override var polyline: MKPolyline { line }
    }

    private func Leg(_ index: Int, through coordinates: [Coordinate]) -> RouteLeg {
        RouteLeg(legIndex: index, fromName: "", toName: "", routes: [FakeRoute(through: coordinates)])
    }

    private func SetValidRoute(_ viewModel: MapViewModel) {
        let start = Fixtures.startPoint
        let dest = Fixtures.destination
        viewModel.startPoint = RoutePoint(
            name: start.name,
            subtitle: "",
            coordinate: start.coordinate.locationCoordinate
        )
        viewModel.destinations = [
            RoutePoint(
                name: dest.name,
                subtitle: "",
                coordinate: dest.coordinate.locationCoordinate
            )
        ]
        viewModel.routeLegs = [Leg(0, through: [start.coordinate, dest.coordinate])]
        viewModel.routedPoints = [viewModel.startPoint].compactMap(\.self) + viewModel.destinations
    }

    @Test func CannotCreateTripWithoutValidPlan() async {
        let service = InMemoryTripService()
        let storage = FakeActiveTripStorage()
        let viewModel = MapViewModel(tripService: service, activeTripStorage: storage)

        #expect(!viewModel.canCreateTrip)

        await #expect(throws: TripServiceError.self) {
            try await viewModel.CreateTrip()
        }
        #expect(viewModel.createdSession == nil)
        #expect(storage.storedSummary == nil)
    }

    @Test func CanCreateTripReflectsReadiness() {
        let viewModel = MapViewModel()
        #expect(!viewModel.canCreateTrip)

        SetValidRoute(viewModel)
        #expect(viewModel.canCreateTrip)

        viewModel.isLoadingRoute = true
        #expect(!viewModel.canCreateTrip)
        viewModel.isLoadingRoute = false

        viewModel.isCreatingTrip = true
        #expect(!viewModel.canCreateTrip)
        viewModel.isCreatingTrip = false
    }

    @Test func CreateTripSavesTripAndRegistersLeader() async throws {
        let service = InMemoryTripService()
        let storage = FakeActiveTripStorage()
        let viewModel = MapViewModel(tripService: service, activeTripStorage: storage)
        SetValidRoute(viewModel)

        let session = try await viewModel.CreateTrip()

        #expect(Trip.IsValidRoomCode(session.state.trip.roomCode))
        #expect(session.state.trip.status == .lobby)
        #expect(session.state.trip.leaderParticipantID == session.myParticipantID)
        #expect(session.state.participants.first?.id == session.myParticipantID)
        #expect(session.state.waypoints.first?.kind == .start)
        #expect(session.state.waypoints.last?.kind == .destination)
        #expect(viewModel.createdSession == session)
    }

    @Test func CreateTripShowsTheGroupTheSavedName() async throws {
        let profiles = FakeProfileStorage(ParticipantProfile(displayName: "Nathan", carDescription: ""))
        let viewModel = MapViewModel(
            tripService: InMemoryTripService(),
            activeTripStorage: FakeActiveTripStorage(),
            profileStorage: profiles
        )
        SetValidRoute(viewModel)

        let session = try await viewModel.CreateTrip()

        #expect(session.state.participants.first?.displayName == "Nathan")
    }

    // MARK: Start point name

    /// A plan that starts at the leader's position, as Set Route does by default.
    private func StartingAtCurrentLocation(_ names: MockStreetNameService) -> MapViewModel {
        let viewModel = MapViewModel(
            tripService: InMemoryTripService(),
            activeTripStorage: FakeActiveTripStorage(),
            profileStorage: FakeProfileStorage(),
            streetNameService: names
        )
        SetValidRoute(viewModel)
        let start = RoutePoint(
            name: String(localized: .waypointCurrentLocation),
            subtitle: "",
            coordinate: Fixtures.startPoint.coordinate.locationCoordinate
        )
        viewModel.startPoint = start
        viewModel.routedPoints = [start] + viewModel.destinations
        return viewModel
    }

    @Test func CurrentLocationIsSavedAsTheRealPlace() async throws {
        // "Current Location" means nothing on a member's phone in the Trip Room.
        let names = MockStreetNameService(results: [.success("Jalan Citraraya Utama")])

        let session = try await StartingAtCurrentLocation(names).CreateTrip()

        #expect(session.state.waypoints.first?.name == "Jalan Citraraya Utama")
        #expect(names.requestedCoordinates == [Fixtures.startPoint.coordinate])
    }

    @Test func PlannerKeepsSayingCurrentLocation() async throws {
        let viewModel = StartingAtCurrentLocation(MockStreetNameService(results: [.success("Jalan Citraraya Utama")]))

        try await viewModel.CreateTrip()

        #expect(viewModel.startPoint?.name == String(localized: .waypointCurrentLocation))
    }

    @Test(arguments: [Result<String?, MockStreetNameService.LookupFailed>.success(nil), .failure(.init())])
    func UnknownPlaceIsCalledTheLeadersStartingPoint(
        result: Result<String?, MockStreetNameService.LookupFailed>
    ) async throws {
        // A failed name lookup must not stop the trip, and must not say "Current Location" either.
        let session = try await StartingAtCurrentLocation(MockStreetNameService(results: [result])).CreateTrip()

        #expect(session.state.waypoints.first?.name == "Leader's starting point")
    }

    @Test func SearchedStartPointKeepsItsName() async throws {
        let names = MockStreetNameService()
        let viewModel = MapViewModel(
            tripService: InMemoryTripService(),
            activeTripStorage: FakeActiveTripStorage(),
            profileStorage: FakeProfileStorage(),
            streetNameService: names
        )
        SetValidRoute(viewModel)

        let session = try await viewModel.CreateTrip()

        #expect(session.state.waypoints.first?.name == Fixtures.startPoint.name)
        #expect(names.requestedCoordinates.isEmpty)
    }

    @Test func CreateTripPersistsActiveTripSummary() async throws {
        let service = InMemoryTripService()
        let storage = FakeActiveTripStorage()
        let viewModel = MapViewModel(tripService: service, activeTripStorage: storage)
        SetValidRoute(viewModel)

        let session = try await viewModel.CreateTrip()

        let saved = try #require(storage.storedSummary)
        #expect(saved.tripID == session.state.trip.id)
        #expect(saved.myParticipantID == session.myParticipantID)
        #expect(saved.roomCode == session.state.trip.roomCode)
        #expect(saved.isLeader == true)
        #expect(saved.status == .lobby)
        #expect(saved.routeCoordinates == session.state.route?.polyline)
        #expect(saved.routeCoordinates?.isEmpty == false)
    }

    @Test func CreateTripHandlesServiceError() async {
        let service = InMemoryTripService()
        service.simulatedFailure = .noNetwork
        let storage = FakeActiveTripStorage()
        let viewModel = MapViewModel(tripService: service, activeTripStorage: storage)
        SetValidRoute(viewModel)

        await #expect(throws: Error.self) {
            try await viewModel.CreateTrip()
        }

        #expect(viewModel.createdSession == nil)
        #expect(viewModel.errorMessage != nil)
    }
}
