//
//  TripMapViewModel+Display.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 29/10/26.
//

import Foundation

// What the map reads straight from the trip state. It lives in its own file so `TripMapViewModel.swift` stays under
// SwiftLint's 400-line limit while everything that changes the trip stays private there.
extension TripMapViewModel {
    var cameraMode: CameraMode { camera.mode }
    var followDistance: Double { camera.followDistance }

    /// Which way this phone's car faces, in degrees clockwise from north: its GPS course while driving, or the
    /// direction of the road ahead while standing still, never the phone's magnetic compass.
    var myHeading: Double {
        if let course = myReading?.course ?? state?.participants.first(where: { $0.id == myParticipantID })?.course {
            return course
        }
        let path = routeAhead
        guard let start = path.first, let next = path.dropFirst().first(where: { $0 != start }) else { return 0 }
        return (PathTurns.Bearing(from: start, to: next) + 360).truncatingRemainder(dividingBy: 360)
    }

    var waypoints: [Waypoint] {
        state?.waypoints.sorted { $0.orderIndex < $1.orderIndex } ?? []
    }

    /// The road path; before a route exists, the straight line through the waypoints.
    var route: [Coordinate] {
        state?.route?.polyline ?? waypoints.map(\.coordinate)
    }

    /// The route from this phone's car on, which is all the map draws, as in Apple Maps; the whole route until
    /// the car's position is known.
    ///
    /// A member's line follows the leader's footprint to the leader, and starts with a way back after a wrong turn.
    var routeAhead: [Coordinate] {
        guard let myCoordinate else { return route }
        guard isLeader == false, let state else { return RoutePosition.RouteAhead(of: myCoordinate, on: route) }
        return following.RouteAhead(from: myCoordinate, in: state)
    }

    /// The stops still ahead: the checkpoints not visited yet and the destination. The start point is never shown on
    /// the road, because after a reroute it is only the leader's position at that moment ("Current Location").
    var upcomingWaypoints: [Waypoint] {
        guard let currentIndex = state?.trip.currentWaypointIndex else { return [] }
        return waypoints.filter { $0.kind != .start && $0.IsVisited(currentWaypointIndex: currentIndex) == false }
    }

    /// The route line every phone draws, the same on each: the group's road from the last car on it to the
    /// destination. A part goes away only once the last car has driven it, so a car in the middle never cuts the line
    /// off for the cars behind it. A car off the road counts where its way back joins the road; offline cars are left
    /// out, as their position is out of date.
    var routeLine: [Coordinate] {
        guard let state, let updatedAt else { return route }
        let path = state.groupPath
        let lastCar = state.participants
            .compactMap { LinePoint(of: $0, in: state, at: updatedAt) }
            .compactMap { point in RoutePosition.Locate(point, on: path).map { (point: point, position: $0) } }
            .min { $0.position.distanceAlongRoute < $1.position.distanceAlongRoute }
        guard let lastCar else { return path }
        return RoutePosition.RouteAhead(of: lastCar.point, on: path)
    }

    /// This member's own way back, from their car to where it joins the group's road, drawn like the route line.
    var myWayBack: [Coordinate] {
        guard let wayBack = following.wayBack, let myCoordinate else { return [] }
        return RoutePosition.RouteAhead(of: myCoordinate, on: wayBack)
    }

    /// Where a car holds the route line back: where it is, or where its way back joins the road. `nil` for a car
    /// without a position, or another car that is offline.
    private func LinePoint(of car: Participant, in state: TripState, at date: Date) -> Coordinate? {
        if car.id == myParticipantID {
            return following.wayBack?.last ?? myCoordinate
        }
        guard car.IsOnline(at: date) else { return nil }
        if car.IsLeader(in: state.trip) == false, let rejoin = car.wayBack.last { return rejoin }
        return car.coordinate
    }

    /// `true` while a new route is on its way: the leader's reroute, or a member's way back to the group's road. The
    /// turn card then says "Rerouting…" instead of an old turn.
    var isRerouting: Bool {
        following.isFindingWayBack || (isLeader && reroute?.isRerouting == true)
    }

    /// Where each other member who left the group's road is being sent, so everyone sees how that car will catch up.
    /// This phone's own way back is `myWayBack`. Offline cars are left out: their last position is out of date, and so
    /// is their way back.
    var wayBacks: [CarWayBack] {
        guard let state, let updatedAt else { return [] }
        return state.participants.compactMap { car in
            guard car.id != myParticipantID, car.wayBack.isEmpty == false, car.IsLeader(in: state.trip) == false,
                  car.IsOnline(at: updatedAt) else { return nil }
            let left = car.coordinate.map { RoutePosition.RouteAhead(of: $0, on: car.wayBack) }
            return CarWayBack(id: car.id, path: left ?? car.wayBack, carColor: CarColor(of: car, in: state))
        }
    }

    var destinationName: String? {
        state?.destination?.name
    }

    var isLeader: Bool {
        state?.trip.leaderParticipantID == myParticipantID
    }

    /// This phone's car: its own latest GPS reading, or its position in the trip without one.
    var myCoordinate: Coordinate? {
        myReading?.coordinate ?? state?.participants.first { $0.id == myParticipantID }?.coordinate
    }

    /// `true` until the first trip update arrives.
    var isLoading: Bool {
        state == nil
    }

    /// Only the leader can change the route, while the trip is open and once their position is known.
    /// "I've Arrived" shows in the pulled-up card within 1 km of the destination, until the car has arrived.
    var canMarkArrived: Bool {
        closeReason == nil && manualArrival.CanMark(in: state, from: myCoordinate)
    }

    /// "I've Arrived": asks first, saying how far the destination's point is.
    func RequestMarkArrived() {
        manualArrival.Request(in: state, from: myCoordinate)
    }

    var canEditRoute: Bool {
        isLeader && closeReason == nil && myCoordinate != nil
    }

    /// The trip as the Trip Room opens it, once the map closed to go back there after a New Destination.
    var tripRoomSession: TripSession? {
        guard closeReason == .backToTripRoom, let state else { return nil }
        return TripSession(myParticipantID: myParticipantID, state: state)
    }

    /// `true` while the phone shares its GPS, so the camera follows the phone's own location, as in Apple Maps;
    /// otherwise (previews and the simulated drive) it follows this car's position in the trip.
    var followsPhoneLocation: Bool {
        locationSharer != nil
    }

    /// `true` while this phone cannot send its position, so the other phones see it standing still and its own
    /// view of the other cars is probably out of date too. Hides as soon as a send works again.
    var isConnectionLost: Bool {
        locationSharer?.lastError != nil
    }

    /// `true` while Precise Location is off: this phone's car is not shared, and the map asks to turn it on.
    var isLocationImprecise: Bool {
        locationSharer?.isLocationImprecise ?? false
    }

    /// A pin for every car that has sent a position; members without one yet have no pin.
    var carPins: [TripMapCarPin] {
        guard let state, let updatedAt else { return [] }
        return state.participants.compactMap { participant in
            guard let coordinate = participant.coordinate else { return nil }
            let isMe = participant.id == myParticipantID
            return TripMapCarPin(
                id: participant.id,
                displayName: state.DisplayName(of: participant),
                coordinate: coordinate,
                motionState: participant.motionState,
                course: isMe ? myHeading : participant.course,
                isLeader: participant.IsLeader(in: state.trip),
                isMe: isMe,
                isOffline: participant.IsOnline(at: updatedAt) == false,
                isAlerting: alerts.IsShared(participant, in: state, at: updatedAt),
                carColor: CarColor(of: participant, in: state)
            )
        }
    }

    /// Worked out from the whole group, so a member keeps their color before everyone has sent a position.
    func CarColor(of participant: Participant, in state: TripState) -> TripMapCarPin.CarColor {
        let members = state.participants.filter { $0.IsLeader(in: state.trip) == false }
        guard let index = members.firstIndex(where: { $0.id == participant.id }) else { return .yellow }
        return .ForMember(atIndex: index)
    }

    /// The robots and the count on the top card, or `nil` until this phone's car has arrived.
    var arrivalProgress: TripMapArrivalProgress? {
        guard let state, arrivalCard != nil else { return nil }
        let robots = arrivalOrder.ids.prefix(TripMapArrivalProgress.maxRobots).compactMap { id in
            state.participants.first { $0.id == id }.map {
                TripMapArrivalProgress.Robot(id: id, carColor: CarColor(of: $0, in: state))
            }
        }
        return TripMapArrivalProgress(
            robots: robots,
            arrivedCount: arrivalOrder.ids.count,
            totalCount: state.participants.count
        )
    }

    /// The status card of the tapped car, or `nil` while no car is tapped.
    ///
    /// The street and time left appear once they are looked up; an offline car shows when it was last seen instead.
    var selectedCarStatus: TripMapCarStatus? {
        SelectedCar().flatMap(CarStatus)
    }

    /// What a car is doing, with the street and time left once they are looked up for it.
    private func CarStatus(of car: Participant) -> TripMapCarStatus? {
        guard let state, let updatedAt else { return nil }
        let displayName = state.DisplayName(of: car)
        guard car.IsOnline(at: updatedAt) else {
            let lastSeen = Duration.seconds(updatedAt.timeIntervalSince(car.lastSeenAt))
            return TripMapCarStatus(
                id: car.id,
                displayName: displayName,
                activity: .offline(lastSeen: lastSeen),
                carDescription: car.carDescription,
                carColor: CarColor(of: car, in: state)
            )
        }
        let lookup = carLookups[car.id]
        let activity: TripMapCarStatus.Activity = car.motionState == .driving
            ? .driving(street: lookup?.street)
            : .stopped(street: lookup?.street)
        return TripMapCarStatus(
            id: car.id,
            displayName: displayName,
            activity: activity,
            timeLeft: lookup?.timeLeft,
            carDescription: car.carDescription,
            carColor: CarColor(of: car, in: state)
        )
    }

    /// The one formation alert banner under the turn card, or `nil` when there is none to show.
    var alertBanner: TripMapAlerts.Banner? {
        guard let state, let updatedAt else { return nil }
        return alerts.Banner(in: state, at: updatedAt)
    }

    /// The notice under the turn card. A formation alert stays on top, so the notice waits until it has gone; a car
    /// that has stopped matters less than a notice.
    var noticeBanner: TripMapNotice? {
        guard let state, let updatedAt else { return nil }
        if let alertBanner {
            guard case .carStopped = alertBanner else { return nil }
        }
        return notices.Notice(
            in: state,
            me: myParticipantID,
            rerouteFailed: reroute?.hasFailed ?? false,
            at: updatedAt
        )
    }

    /// What the bottom card shows once this phone's car has arrived, or `nil` while it is on the way.
    var arrivalCard: ArrivalCard? {
        guard let state, let updatedAt else { return nil }
        let arrival = TripMapArrival.Check(state, myParticipantID: myParticipantID, at: updatedAt)
        guard arrival.hasArrived else { return nil }
        return arrival.everyoneHasArrived ? .everyoneArrived : .waitingForEveryone
    }

    /// Looks up the tapped car's street and time left (see `LookUpCar`).
    func RefreshSelectedCarStatus() async {
        guard let car = SelectedCar() else { return }
        await LookUpCar(car.id)
    }

    /// The tapped car, while it is still in the trip with a position on the map.
    func SelectedCar() -> Participant? {
        guard let selectedCarID else { return nil }
        return state?.participants.first { $0.id == selectedCarID && $0.coordinate != nil }
    }
}
