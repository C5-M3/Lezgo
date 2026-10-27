import Foundation
import Observation

/// State and logic for the trip map (Trip Started screen).
///
/// It listens to a `TripMapService` for the trip and every car, and asks a `TripMapNavigator` for the next turn and
/// the time left from this phone's car. Both arrive through the initializer, so tests pass in mocks, previews pass
/// in the simulated drive, and the live app will pass in the real services once they land.
@Observable
final class TripMapViewModel {
    private(set) var snapshot: TripMapSnapshot?
    private(set) var guidance: TripMapGuidance?
    private(set) var cameraMode: TripMapCameraMode = .followMyCar
    /// When the latest snapshot arrived; offline cars are judged against this time.
    private var updatedAt: Date?

    private let tripID: UUID
    private let service: any TripMapService
    private let navigator: any TripMapNavigator
    private let clock: () -> Date

    init(
        tripID: UUID,
        service: any TripMapService,
        navigator: any TripMapNavigator,
        locationSharer: LocationSharer? = nil,
        clock: @escaping () -> Date = { .now }
    ) {
        self.tripID = tripID
        self.service = service
        self.navigator = navigator
        self.clock = clock
    }

    var carPins: [TripMapCarPin] {
        guard let snapshot, let updatedAt else { return [] }
        return snapshot.cars.map { car in
            TripMapCarPin(
                id: car.id,
                displayName: car.displayName,
                coordinate: car.coordinate,
                motionState: car.motionState,
                isLeader: car.id == snapshot.leaderParticipantID,
                isMe: car.id == snapshot.myParticipantID,
                isOffline: car.IsOnline(at: updatedAt) == false
            )
        }
    }

    var waypoints: [TripMapWaypoint] {
        snapshot?.waypoints.sorted { $0.orderIndex < $1.orderIndex } ?? []
    }

    var route: [TripMapCoordinate] {
        snapshot?.route ?? []
    }

    var destinationName: String? {
        snapshot?.waypoints.first { $0.kind == .destination }?.name
    }

    var isLeader: Bool {
        guard let snapshot else { return false }
        return snapshot.myParticipantID == snapshot.leaderParticipantID
    }

    var myCoordinate: TripMapCoordinate? {
        guard let snapshot else { return nil }
        return snapshot.cars.first { $0.id == snapshot.myParticipantID }?.coordinate
    }

    /// `true` until the first trip update arrives.
    var isLoading: Bool {
        snapshot == nil
    }

    /// Whether the leader has already moved the trip past this waypoint.
    func IsVisited(_ waypoint: TripMapWaypoint) -> Bool {
        guard let snapshot else { return false }
        return waypoint.IsVisited(currentWaypointIndex: snapshot.currentWaypointIndex)
    }

    /// Listens to the trip until the stream finishes or the task is cancelled.
    func Start() async {
        for await snapshot in service.TripUpdates(tripID: tripID) {
            self.snapshot = snapshot
            updatedAt = clock()
            await RefreshGuidance()
        }
    }

    func ShowWholeRoute() {
        cameraMode = .wholeRoute
    }

    func FollowMyCar() {
        cameraMode = .followMyCar
    }

    /// Called when the person pans or zooms the map by hand.
    func StopFollowing() {
        cameraMode = .free
    }

    /// Asks for new guidance from my car. When routing fails, the last guidance stays on screen: an old turn and
    /// time are more useful to a driver than an empty card, and the next update tries again a second later.
    private func RefreshGuidance() async {
        guard let snapshot, let myCoordinate else { return }
        guard let newGuidance = try? await navigator.Guidance(from: myCoordinate, along: snapshot) else { return }
        guidance = newGuidance
    }
}
