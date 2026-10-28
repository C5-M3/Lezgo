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
    /// The car whose status card is open, or `nil` while it is closed.
    private(set) var selectedCarID: UUID?
    /// When the latest state arrived; offline cars are judged against this time.
    private var updatedAt: Date?
    /// The last street and time left of every car tapped so far.
    private var carLookups: [UUID: CarLookup] = [:]
    /// This phone's formation alert and the banners closed with ⓧ.
    private var alerts: TripMapAlerts
    /// The waypoint index this leader's phone last asked the trip to move to, so it asks once per checkpoint.
    private var requestedWaypointIndex: Int?

    /// How often a tapped car's street and time left are looked up again (`specs/UserStories.md` → US-06, "Data").
    private static let carLookupInterval: TimeInterval = 30

    /// The participant who uses this phone.
    let myParticipantID: UUID
    private let tripID: UUID
    private let tripService: any TripService
    private let navigator: any TripMapNavigator
    private let streetNameService: any StreetNameService
    /// Sends this phone's position while the map is open; `nil` in previews and with the simulated drive.
    private let locationSharer: LocationSharer?
    private let clock: () -> Date

    init(
        tripID: UUID,
        myParticipantID: UUID,
        tripService: any TripService,
        navigator: any TripMapNavigator,
        streetNameService: any StreetNameService,
        locationSharer: LocationSharer? = nil,
        clock: @escaping () -> Date = { .now }
    ) {
        self.tripID = tripID
        self.myParticipantID = myParticipantID
        self.tripService = tripService
        self.navigator = navigator
        self.streetNameService = streetNameService
        self.locationSharer = locationSharer
        self.clock = clock
        alerts = TripMapAlerts(myParticipantID: myParticipantID)
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
                isOffline: participant.IsOnline(at: updatedAt) == false,
                isAlerting: alerts.IsShared(participant, at: updatedAt)
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

    /// The status card of the tapped car, or `nil` while no car is tapped.
    ///
    /// The street and time left appear once they are looked up; an offline car shows when it was last seen instead.
    var selectedCarStatus: TripMapCarStatus? {
        guard let updatedAt, let car = SelectedCar() else { return nil }
        guard car.IsOnline(at: updatedAt) else {
            let lastSeen = Duration.seconds(updatedAt.timeIntervalSince(car.lastSeenAt))
            return TripMapCarStatus(id: car.id, displayName: car.displayName, activity: .offline(lastSeen: lastSeen))
        }
        let lookup = carLookups[car.id]
        let activity: TripMapCarStatus.Activity = car.motionState == .driving
            ? .driving(street: lookup?.street)
            : .stopped(street: lookup?.street)
        return TripMapCarStatus(
            id: car.id,
            displayName: car.displayName,
            activity: activity,
            timeLeft: lookup?.timeLeft
        )
    }

    /// The one formation alert banner under the turn card, or `nil` when there is none to show.
    var alertBanner: TripMapAlerts.Banner? {
        guard let state, let updatedAt else { return nil }
        return alerts.Banner(in: state, at: updatedAt)
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
            CloseCardOfGoneCar()
            await UpdateMyAlert()
            await PassCheckpointIfReached()
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

    /// ⓧ on the alert banner: hides it until that alert happens again.
    func DismissAlertBanner() {
        guard let alertBanner else { return }
        alerts.Close(alertBanner)
    }

    /// Called when the person pans or zooms the map by hand.
    func StopFollowing() {
        cameraMode = .free
    }

    /// Opens the status card of a tapped car, or closes it with `nil` (tap elsewhere or swipe down). The camera stays
    /// as it is.
    func SelectCar(_ carID: UUID?) {
        guard carID != selectedCarID else { return }
        selectedCarID = carID
    }

    /// Keeps the tapped car's street and time left up to date while its card is open. The view runs this in a task
    /// tied to the tapped car, so it stops when the card closes or another car is tapped, and ends at once while no
    /// card is open.
    func TrackSelectedCar() async {
        while selectedCarID != nil, Task.isCancelled == false {
            await RefreshSelectedCarStatus()
            try? await Task.sleep(for: .seconds(Self.carLookupInterval))
        }
    }

    /// Looks up the tapped car's street and time left, at most every 30 seconds per car, because both need the
    /// network and Apple limits how often an app may ask. A failed lookup keeps what was known before. An offline
    /// car is not looked up: its position is out of date.
    func RefreshSelectedCarStatus() async {
        guard let state, let updatedAt, let car = SelectedCar(), let coordinate = car.coordinate,
              car.IsOnline(at: updatedAt) else { return }
        let now = clock()
        if let lookedUpAt = carLookups[car.id]?.lookedUpAt, now.timeIntervalSince(lookedUpAt) < Self.carLookupInterval {
            return
        }
        let street = try? await streetNameService.StreetName(at: coordinate)
        let timeLeft = try? await navigator.Guidance(from: coordinate, along: state).timeLeft
        // A lookup cancelled by tapping another car is not saved, so tapping this car again looks it up at once.
        guard Task.isCancelled == false else { return }
        let previous = carLookups[car.id]
        carLookups[car.id] = CarLookup(
            street: street ?? previous?.street,
            timeLeft: timeLeft ?? previous?.timeLeft,
            lookedUpAt: now
        )
    }

    /// The tapped car, while it is still in the trip with a position on the map.
    private func SelectedCar() -> Participant? {
        guard let selectedCarID else { return nil }
        return state?.participants.first { $0.id == selectedCarID && $0.coordinate != nil }
    }

    /// A tapped car that left the trip, or was removed, closes its card.
    private func CloseCardOfGoneCar() {
        guard selectedCarID != nil, SelectedCar() == nil else { return }
        SelectCar(nil)
    }

    /// Works out this member's alert from the new state and saves it when it changed, so the other phones see it.
    /// A failed save is not shown: the next update, a second later, tries again.
    private func UpdateMyAlert() async {
        guard let state, let alert = alerts.Update(state) else { return }
        guard (try? await tripService.SetAlert(alert, participantID: myParticipantID, tripID: tripID)) != nil else {
            return
        }
        alerts.Saved(alert)
    }

    /// Checkpoints follow the leader: within 20 m of the next one, the leader's phone marks it visited for everyone.
    /// A failed request is tried again on the next update.
    private func PassCheckpointIfReached() async {
        guard isLeader, let state, let myCoordinate, let checkpoint = state.nextCheckpoint,
              myCoordinate.Distance(to: checkpoint.coordinate) <= TripMapArrival.radius else { return }
        let nextIndex = checkpoint.orderIndex + 1
        guard requestedWaypointIndex.map({ $0 < nextIndex }) ?? true else { return }
        requestedWaypointIndex = nextIndex
        if (try? await tripService.AdvanceCheckpoint(to: nextIndex, tripID: tripID, by: myParticipantID)) == nil {
            requestedWaypointIndex = nil
        }
    }

    /// Asks for new guidance from my car. When routing fails, the last guidance stays on screen: an old turn and
    /// time are more useful to a driver than an empty card, and the next update tries again a second later.
    private func RefreshGuidance() async {
        guard let state, let myCoordinate else { return }
        guard let newGuidance = try? await navigator.Guidance(from: myCoordinate, along: state) else { return }
        guidance = newGuidance
    }
}

// MARK: Nested types

extension TripMapViewModel {
    /// What was last looked up about a tapped car, and when.
    private struct CarLookup {
        var street: String?
        var timeLeft: Duration?
        var lookedUpAt: Date
    }

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
