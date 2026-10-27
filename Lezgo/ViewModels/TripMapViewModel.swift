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
    /// The confirmation to show before leaving, or `nil`.
    private(set) var leaveConfirmation: TripMapLeaveConfirmation?
    /// Set once the map should close and the phone return to Home; sharing stops at the same time.
    private(set) var closeReason: TripMapCloseReason?
    /// Why leaving failed, for example no network; the map stays open so the person can try again.
    private(set) var leaveErrorMessage: String?
    /// `true` while an exit or end request is on its way, so a second tap does nothing.
    private var isLeaving = false
    /// When the latest snapshot arrived; offline cars are judged against this time.
    private var updatedAt: Date?

    private let tripID: UUID
    private let service: any TripMapService
    private let navigator: any TripMapNavigator
    /// Sends this phone's position while the map is open; `nil` in previews and with the simulated drive.
    private let locationSharer: LocationSharer?
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
        self.locationSharer = locationSharer
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

    /// What the bottom card shows once this phone's car has arrived, or `nil` while it is on the way.
    var arrivalCard: TripMapArrivalCard? {
        guard let snapshot, let updatedAt else { return nil }
        let arrival = TripMapArrival.Check(snapshot, at: updatedAt)
        guard arrival.hasArrived else { return nil }
        return arrival.everyoneHasArrived ? .everyoneArrived : .waitingForEveryone
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

    /// Follows the trip, and shares this phone's position when a sharer is given, until the stream finishes or the
    /// task is cancelled.
    func Start() async {
        await withTaskGroup(of: Void.self) { group in
            if let locationSharer {
                group.addTask { await locationSharer.Run() }
            }
            group.addTask { await self.FollowTrip() }
            // The trip stream ends when the trip closes on this phone; then sharing stops too.
            await group.next()
            group.cancelAll()
        }
    }

    /// Follows the trip until it closes on this phone; then `Start` stops sharing the position too.
    private func FollowTrip() async {
        for await snapshot in service.TripUpdates(tripID: tripID) {
            self.snapshot = snapshot
            updatedAt = clock()
            NoticeTripClosed(snapshot)
            if closeReason != nil { return }
            await RefreshGuidance()
        }
    }

    /// The leader ended the trip, or removed this member, from another phone.
    private func NoticeTripClosed(_ snapshot: TripMapSnapshot) {
        guard closeReason == nil else { return }
        if snapshot.status == .ended || snapshot.status == .cancelled {
            closeReason = .endedByLeader
        } else if snapshot.memberIDs.contains(snapshot.myParticipantID) == false {
            closeReason = .removed
        }
    }

    func ShowWholeRoute() {
        cameraMode = .wholeRoute
    }

    func FollowMyCar() {
        cameraMode = .followMyCar
    }

    /// "Exit Trip" (member) or "End Trip" (leader): asks for confirmation first.
    func RequestLeave() {
        guard closeReason == nil, let snapshot else { return }
        guard isLeader else {
            leaveConfirmation = .exitTrip
            return
        }
        let arrival = TripMapArrival.Check(snapshot, at: updatedAt ?? clock())
        leaveConfirmation = .endTrip(everyoneHasArrived: arrival.everyoneHasArrived)
    }

    /// "Cancel" on the confirmation: nothing changes.
    func CancelLeave() {
        leaveConfirmation = nil
    }

    /// "Confirm" on the confirmation: leaves or ends the trip, then closes the map. On failure the map stays open
    /// with a message, so nobody is stuck believing they left.
    func ConfirmLeave() async {
        guard let confirmation = leaveConfirmation, let snapshot, isLeaving == false else { return }
        isLeaving = true
        defer { isLeaving = false }
        do {
            switch confirmation {
            case .exitTrip:
                try await service.ExitTrip(tripID: tripID, participantID: snapshot.myParticipantID)
                closeReason = .exited
            case .endTrip:
                try await service.EndTrip(tripID: tripID, by: snapshot.myParticipantID)
                closeReason = .ended
            }
            leaveErrorMessage = nil
        } catch {
            leaveErrorMessage = String(localized: TripServiceError(cloudKitError: error).message)
        }
        leaveConfirmation = nil
    }

    /// "OK" on the message that leaving failed.
    func DismissLeaveError() {}

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
