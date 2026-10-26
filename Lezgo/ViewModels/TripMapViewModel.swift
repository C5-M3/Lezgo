import Foundation
import Observation

/// State and logic for the trip map (Trip Started screen).
@Observable
final class TripMapViewModel {
    private(set) var snapshot: TripMapSnapshot?
    private(set) var guidance: TripMapGuidance?
    private(set) var cameraMode: TripMapCameraMode = .followMyCar

    private let tripID: UUID
    private let service: any TripMapService
    private let navigator: any TripMapNavigator
    private let clock: () -> Date

    init(
        tripID: UUID,
        service: any TripMapService,
        navigator: any TripMapNavigator,
        clock: @escaping () -> Date = { .now }
    ) {
        self.tripID = tripID
        self.service = service
        self.navigator = navigator
        self.clock = clock
    }

    var carPins: [TripMapCarPin] { [] }
    var waypoints: [TripMapWaypoint] { [] }
    var route: [TripMapCoordinate] { [] }
    var destinationName: String? { nil }
    var isLeader: Bool { false }
    var myCoordinate: TripMapCoordinate? { nil }
    /// `true` until the first trip update arrives.
    var isLoading: Bool { false }

    /// Whether the leader has already moved the trip past this waypoint.
    func IsVisited(_ waypoint: TripMapWaypoint) -> Bool { false }

    /// Listens to the trip until the stream finishes or the task is cancelled.
    func Start() async {}

    func ShowWholeRoute() {}

    func FollowMyCar() {}

    /// Called when the person pans or zooms the map by hand.
    func StopFollowing() {}
}
