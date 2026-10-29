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
    /// When this phone, as leader, moves the trip past a checkpoint.
    private var checkpointProgress = TripMapCheckpointProgress()

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
    /// Reroutes the group when this phone's leader leaves the route; `nil` without a directions service (previews
    /// and the simulated drive, where the leader never leaves the route).
    private let reroute: TripMapReroute?
    private let clock: () -> Date

    init(
        tripID: UUID,
        myParticipantID: UUID,
        tripService: any TripService,
        navigator: any TripMapNavigator,
        streetNameService: any StreetNameService,
        locationSharer: LocationSharer? = nil,
        directionsService: (any DirectionsService)? = nil,
        clock: @escaping () -> Date = { .now }
    ) {
        self.tripID = tripID
        self.myParticipantID = myParticipantID
        self.tripService = tripService
        self.navigator = navigator
        self.streetNameService = streetNameService
        self.locationSharer = locationSharer
        reroute = directionsService.map {
            TripMapReroute(tripID: tripID, tripService: tripService, directionsService: $0)
        }
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
                isAlerting: alerts.IsShared(participant, in: state, at: updatedAt)
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

    /// Checkpoints follow the leader: the leader's phone marks each one visited for everyone. A failed request is
    /// tried again on the next update.
    private func PassCheckpointIfReached() async {
        guard isLeader, let state, let myCoordinate else {
            checkpointProgress.Reset()
            return
        }
        guard let waypointIndex = checkpointProgress.Update(state, leaderCoordinate: myCoordinate) else { return }
        if (try? await tripService.AdvanceCheckpoint(to: waypointIndex, tripID: tripID, by: myParticipantID)) == nil {
            checkpointProgress.Failed()
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

// MARK: Following the trip

extension TripMapViewModel {
    /// Follows the trip until it closes on this phone; then `Start` stops sharing the position too.
    ///
    /// The reroute runs beside the trip updates, so a slow directions request never holds back the cars, alerts
    /// and guidance on the map.
    private func FollowTrip() async {
        let (rerouteStates, rerouteInput) = AsyncStream.makeStream(of: TripState.self)
        await withTaskGroup(of: Void.self) { group in
            if let reroute {
                group.addTask { await reroute.Run(rerouteStates, myParticipantID: self.myParticipantID) }
            }
            await ApplyTripUpdates(rerouteInput: rerouteInput)
            rerouteInput.finish()
            // A closed trip is never rerouted, even with states still waiting.
            if closeReason != nil { group.cancelAll() }
        }
    }

    private func ApplyTripUpdates(rerouteInput: AsyncStream<TripState>.Continuation) async {
        for await newState in tripService.TripUpdates(tripID: tripID) {
            // A late fetch can still carry the old route; phones never go back to an older version.
            if let state, newState.trip.routeVersion < state.trip.routeVersion { continue }
            state = newState
            updatedAt = clock()
            NoticeTripClosed(newState)
            if closeReason != nil { return }
            CloseCardOfGoneCar()
            await UpdateMyAlert()
            await PassCheckpointIfReached()
            rerouteInput.yield(newState)
            await RefreshGuidance()
        }
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
}
