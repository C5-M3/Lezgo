import Foundation
import Testing
@testable import Lezgo

struct TripServiceMapAdapterTests {
    private func State(status: TripStatus = .inTrip) -> TripState {
        SampleTrip.State(status: status, now: TripFixtures.now)
    }

    @Test func SnapshotKeepsTheTripAndWhoIAm() {
        let state = State()

        let snapshot = TripServiceMapAdapter.MakeSnapshot(from: state, myParticipantID: SampleTrip.budiID)

        #expect(snapshot.tripID == SampleTrip.tripID)
        #expect(snapshot.leaderParticipantID == SampleTrip.agusID)
        #expect(snapshot.myParticipantID == SampleTrip.budiID)
        #expect(snapshot.currentWaypointIndex == 1)
        #expect(snapshot.routeVersion == 1)
    }

    @Test(arguments: [TripStatus.inTrip, .ended, .cancelled])
    func SnapshotKeepsTheTripStatus(status: TripStatus) {
        let state = State(status: status)

        let snapshot = TripServiceMapAdapter.MakeSnapshot(from: state, myParticipantID: SampleTrip.budiID)

        #expect(snapshot.status == status)
    }

    @Test func WaypointsKeepTheirOrderKindAndPlace() {
        let state = State()

        let waypoints = TripServiceMapAdapter.MakeSnapshot(from: state, myParticipantID: SampleTrip.budiID).waypoints

        #expect(waypoints.map(\.name) == ["Tunjungan Plaza", "Ciputra World", "Pakuwon mall"])
        #expect(waypoints.map(\.kind) == [.start, .checkpoint, .destination])
        #expect(waypoints.map(\.orderIndex) == [0, 1, 2])
        #expect(waypoints.first?.coordinate.latitude == state.waypoints.first?.coordinate.latitude)
    }

    @Test func CarsCarryNameMotionAndLastSeen() throws {
        let state = State()

        let cars = TripServiceMapAdapter.MakeSnapshot(from: state, myParticipantID: SampleTrip.budiID).cars

        let citra = try #require(cars.first { $0.id == SampleTrip.citraID })
        let source = try #require(state.participants.first { $0.id == SampleTrip.citraID })
        #expect(citra.displayName == "Citra")
        #expect(citra.carDescription == "Red Jazz")
        #expect(citra.lastSeenAt == source.lastSeenAt)
        #expect(citra.motionState == .stopped)
    }

    @Test func CarWithoutAPositionYetIsLeftOut() {
        var state = State()
        state.participants[1].coordinate = nil

        let cars = TripServiceMapAdapter.MakeSnapshot(from: state, myParticipantID: SampleTrip.budiID).cars

        #expect(cars.map(\.displayName) == ["Agus", "Citra"])
    }

    @Test func RouteLineFollowsTheRoute() {
        let state = State()

        let route = TripServiceMapAdapter.MakeSnapshot(from: state, myParticipantID: SampleTrip.budiID).route

        #expect(route.count == state.route?.polyline.count)
        #expect(route.last?.longitude == state.route?.polyline.last?.longitude)
    }

    @Test func MissingRouteFallsBackToTheWaypoints() {
        var state = State()
        state.route = nil

        let route = TripServiceMapAdapter.MakeSnapshot(from: state, myParticipantID: SampleTrip.budiID).route

        #expect(route.count == 3)
    }

    @Test func UpdatesFollowTheTripService() async throws {
        let service = SampleTrip.Service(status: .inTrip, me: SampleTrip.budiID)
        let adapter = TripServiceMapAdapter(tripService: service, myParticipantID: SampleTrip.budiID)

        var updates = adapter.TripUpdates(tripID: SampleTrip.tripID).makeAsyncIterator()
        let first = await updates.next()

        #expect(first?.cars.count == 3)
        #expect(first?.myParticipantID == SampleTrip.budiID)
    }

    // MARK: Leave and end

    private func LatestState(of service: InMemoryTripService) async -> TripState? {
        var updates = service.TripUpdates(tripID: SampleTrip.tripID).makeAsyncIterator()
        return await updates.next()
    }

    @Test func ExitTripTakesMyCarOutOfTheTrip() async throws {
        let service = SampleTrip.Service(status: .inTrip, me: SampleTrip.budiID)
        let adapter = TripServiceMapAdapter(tripService: service, myParticipantID: SampleTrip.budiID)

        try await adapter.ExitTrip(tripID: SampleTrip.tripID, participantID: SampleTrip.budiID)

        let state = await LatestState(of: service)
        #expect(state?.participants.map(\.id) == [SampleTrip.agusID, SampleTrip.citraID])
        #expect(state?.trip.status == .inTrip)
    }

    @Test func EndTripEndsItForEveryone() async throws {
        let service = SampleTrip.Service(status: .inTrip, me: SampleTrip.agusID)
        let adapter = TripServiceMapAdapter(tripService: service, myParticipantID: SampleTrip.agusID)

        try await adapter.EndTrip(tripID: SampleTrip.tripID, by: SampleTrip.agusID)

        let state = await LatestState(of: service)
        #expect(state?.trip.status == .ended)
    }

    @Test func ExitTripPassesTheServiceErrorOn() async {
        let service = SampleTrip.Service(status: .inTrip, me: SampleTrip.agusID)
        let adapter = TripServiceMapAdapter(tripService: service, myParticipantID: SampleTrip.agusID)

        await #expect(throws: TripServiceError.notAllowed) {
            try await adapter.ExitTrip(tripID: SampleTrip.tripID, participantID: SampleTrip.agusID)
        }
    }
}
