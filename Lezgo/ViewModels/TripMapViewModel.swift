//
//  TripMapViewModel.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import Foundation
import Observation

/// State and logic for the trip map (Trip Started screen).
///
/// It follows the trip through the shared `TripService`, and asks a `TripMapNavigator` for the next turn and the
/// time left from this phone's car. Both arrive through the initializer, so tests pass in mocks and previews pass in
/// an `InMemoryTripService` with a simulated drive.
@Observable
final class TripMapViewModel {
    private(set) var state: TripState?
    private(set) var guidance: TripMapGuidance?
    private(set) var cameraMode: CameraMode = .followMyCar
    /// The confirmation to show before leaving, or `nil`.
    private(set) var leaveConfirmation: LeaveConfirmation?
    /// Set once the map should close and the phone return to Home; sharing stops at the same time.
    private(set) var closeReason: CloseReason?
    /// Why leaving failed, for example no network; the map stays open so the person can try again.
    private(set) var leaveErrorMessage: String?
    /// `true` while an exit or end request is on its way; the card's buttons are disabled meanwhile.
    private(set) var isLeaving = false
    /// When the latest state arrived; offline cars are judged against this time.
    private var updatedAt: Date?

    /// The participant who uses this phone.
    let myParticipantID: UUID
    private let tripID: UUID
    private let tripService: any TripService
    private let navigator: any TripMapNavigator
    /// Sends this phone's position while the map is open; `nil` in previews and with the simulated drive.
    private let locationSharer: LocationSharer?
    private let clock: () -> Date

    init(
        tripID: UUID,
        myParticipantID: UUID,
        tripService: any TripService,
        navigator: any TripMapNavigator,
        locationSharer: LocationSharer? = nil,
        clock: @escaping () -> Date = { .now }
    ) {
        self.tripID = tripID
        self.myParticipantID = myParticipantID
        self.tripService = tripService
        self.navigator = navigator
        self.locationSharer = locationSharer
        self.clock = clock
    }

    /// A pin for every car that has sent a position; members without one yet have no pin.
    var carPins: [TripMapCarPin] {
        guard let state, let updatedAt else { return [] }
        return state.participants.compactMap { participant in
            guard let coordinate = participant.coordinate else { return nil }
            return TripMapCarPin(
                id: participant.id,
                displayName: participant.displayName,
                coordinate: coordinate,
                motionState: participant.motionState,
                isLeader: participant.IsLeader(in: state.trip),
                isMe: participant.id == myParticipantID,
                isOffline: participant.IsOnline(at: updatedAt) == false
            )
        }
    }

    var waypoints: [Waypoint] {
        state?.waypoints.sorted { $0.orderIndex < $1.orderIndex } ?? []
    }

    /// The road path; before a route exists, the straight line through the waypoints.
    var route: [Coordinate] {
        state?.route?.polyline ?? waypoints.map(\.coordinate)
    }

    var destinationName: String? {
        state?.destination?.name
    }

    var isLeader: Bool {
        state?.trip.leaderParticipantID == myParticipantID
    }

    var myCoordinate: Coordinate? {
        state?.participants.first { $0.id == myParticipantID }?.coordinate
    }

    /// What the bottom card shows once this phone's car has arrived, or `nil` while it is on the way.
    var arrivalCard: ArrivalCard? {
        guard let state, let updatedAt else { return nil }
        let arrival = TripMapArrival.Check(state, myParticipantID: myParticipantID, at: updatedAt)
        guard arrival.hasArrived else { return nil }
        return arrival.everyoneHasArrived ? .everyoneArrived : .waitingForEveryone
    }

    /// `true` until the first trip update arrives.
    var isLoading: Bool {
        state == nil
    }

    /// Whether the leader has already moved the trip past this waypoint.
    func IsVisited(_ waypoint: Waypoint) -> Bool {
        guard let state else { return false }
        return waypoint.IsVisited(currentWaypointIndex: state.trip.currentWaypointIndex)
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
        for await newState in tripService.TripUpdates(tripID: tripID) {
            state = newState
            updatedAt = clock()
            NoticeTripClosed(newState)
            if closeReason != nil { return }
            await RefreshGuidance()
        }
    }

    /// The leader ended the trip, or removed this member, from another phone.
    ///
    /// While this phone's own exit or end is on its way, the update it causes can arrive first; `ConfirmLeave` sets
    /// the reason then, so the person is not told they were removed or that the leader ended the trip.
    private func NoticeTripClosed(_ newState: TripState) {
        guard closeReason == nil, isLeaving == false else { return }
        if newState.trip.status.isOpen == false {
            // The leader only sees this when their own end request failed on the way back, so it closes quietly.
            closeReason = newState.trip.leaderParticipantID == myParticipantID ? .ended : .endedByLeader
        } else if newState.participants.contains(where: { $0.id == myParticipantID }) == false {
            closeReason = .removed
        }
        // An open "Exit trip?" would hide the message about why the map closed.
        if closeReason != nil {
            leaveConfirmation = nil
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
        guard closeReason == nil, isLeaving == false, let state else { return }
        guard isLeader else {
            leaveConfirmation = .exitTrip
            return
        }
        let arrival = TripMapArrival.Check(state, myParticipantID: myParticipantID, at: updatedAt ?? clock())
        leaveConfirmation = .endTrip(everyoneHasArrived: arrival.everyoneHasArrived)
    }

    /// "Cancel" on the confirmation: nothing changes.
    func CancelLeave() {
        leaveConfirmation = nil
    }

    /// "Confirm" on the confirmation: leaves or ends the trip, then closes the map. On failure the map stays open
    /// with a message, so nobody is stuck believing they left.
    ///
    /// The view passes the confirmation it showed, because the alert closes (and clears `leaveConfirmation`) before
    /// the task that calls this runs.
    func ConfirmLeave(_ confirmation: LeaveConfirmation) async {
        guard closeReason == nil, state != nil, isLeaving == false else { return }
        isLeaving = true
        defer { isLeaving = false }
        do {
            switch confirmation {
            case .exitTrip:
                try await tripService.ExitTrip(tripID: tripID, participantID: myParticipantID)
                closeReason = .exited
            case .endTrip:
                try await tripService.EndTrip(tripID: tripID, by: myParticipantID)
                closeReason = .ended
            }
            leaveErrorMessage = nil
        } catch {
            leaveErrorMessage = String(localized: TripServiceError(cloudKitError: error).message)
        }
        leaveConfirmation = nil
    }

    /// "OK" on the message that leaving failed.
    func DismissLeaveError() {
        leaveErrorMessage = nil
    }

    /// Called when the person pans or zooms the map by hand.
    func StopFollowing() {
        cameraMode = .free
    }

    /// Asks for new guidance from my car. When routing fails, the last guidance stays on screen: an old turn and
    /// time are more useful to a driver than an empty card, and the next update tries again a second later.
    private func RefreshGuidance() async {
        guard let state, let myCoordinate else { return }
        guard let newGuidance = try? await navigator.Guidance(from: myCoordinate, along: state) else { return }
        guidance = newGuidance
    }

    // MARK: Nested types

    /// What the trip map camera follows.
    enum CameraMode: Hashable {
        /// The camera stays on this phone's car as it moves.
        case followMyCar
        /// The camera shows the whole route; it no longer moves with the car.
        case wholeRoute
        /// The person moved the map by hand; the camera stays where they left it.
        case free
    }

    /// The confirmation shown before leaving the trip from the map (`specs/UserStories.md` → US-07, "Leave and end").
    enum LeaveConfirmation: Hashable {
        /// A member: "Exit trip?"
        case exitTrip
        /// The leader: "End trip?", or "End trip? Not everyone has arrived yet." when someone is still on the way.
        case endTrip(everyoneHasArrived: Bool)
    }

    /// Why the trip map closed on this phone, which then returns to Home.
    enum CloseReason: Hashable {
        /// This member chose "Exit Trip".
        case exited
        /// This leader chose "End Trip".
        case ended
        /// Another phone, the leader's, ended the trip: "The leader ended the trip."
        case endedByLeader
        /// The leader removed this member: "You were removed from the trip."
        case removed
    }

    /// What the bottom card shows once this phone's car has arrived (`specs/UserStories.md` → US-07, "Arrive").
    enum ArrivalCard: Hashable {
        /// "You have arrived" · "Waiting for everyone to arrive"
        case waitingForEveryone
        /// "Everyone has arrived!" (and, for the leader, "Continue your trip?")
        case everyoneArrived
    }
}
