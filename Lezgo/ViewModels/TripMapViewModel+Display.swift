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

    /// On the leader's phone, the road the leader has driven up to their car: the road the members behind follow,
    /// so the leader can see them on it. Empty on a member's phone, which draws only what is ahead.
    var footprint: [Coordinate] {
        guard isLeader, let state, state.trail.isEmpty == false, let myCoordinate else { return [] }
        return state.trail + [myCoordinate]
    }

    /// `true` while a new route is on its way: the leader's reroute, or a member's way back to the group's road. The
    /// turn card then says "Rerouting…" instead of an old turn.
    var isRerouting: Bool {
        following.isFindingWayBack || (isLeader && reroute?.isRerouting == true)
    }

    /// On the leader's phone, where each member who left the group's road is being sent, so the leader sees how that
    /// car will catch up. Offline cars are left out: their last position is out of date, and so is their way back.
    var memberWayBacks: [MemberWayBack] {
        guard isLeader, let state, let updatedAt else { return [] }
        return state.participants.compactMap { car in
            guard car.wayBack.isEmpty == false, car.IsLeader(in: state.trip) == false,
                  car.IsOnline(at: updatedAt) else { return nil }
            let left = car.coordinate.map { RoutePosition.RouteAhead(of: $0, on: car.wayBack) }
            return MemberWayBack(id: car.id, path: left ?? car.wayBack)
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
    var canEditRoute: Bool {
        isLeader && closeReason == nil && myCoordinate != nil
    }

    /// The trip as the Trip Room opens it, once the map closed to go back there after a New Destination.
    var tripRoomSession: TripSession? {
        guard closeReason == .backToTripRoom, let state else { return nil }
        return TripSession(myParticipantID: myParticipantID, state: state)
    }

    /// This phone's car is the map's own location dot while the phone shares its GPS, as in Apple Maps; otherwise
    /// (previews and the simulated drive) it is a car pin like the others, from the trip.
    var showsMyLocationDot: Bool {
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
            // The location dot already shows this phone's car.
            if showsMyLocationDot, participant.id == myParticipantID { return nil }
            return TripMapCarPin(
                id: participant.id,
                displayName: state.DisplayName(of: participant),
                coordinate: coordinate,
                motionState: participant.motionState,
                course: participant.course,
                isLeader: participant.IsLeader(in: state.trip),
                isMe: participant.id == myParticipantID,
                isOffline: participant.IsOnline(at: updatedAt) == false,
                isAlerting: alerts.IsShared(participant, in: state, at: updatedAt),
                carColor: CarColor(of: participant, in: state)
            )
        }
    }

    /// Worked out from the whole group, so a member keeps their color before everyone has sent a position.
    private func CarColor(of participant: Participant, in state: TripState) -> TripMapCarPin.CarColor {
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

    /// What the bottom card shows once this phone's car has arrived, or `nil` while it is on the way.
    var arrivalCard: ArrivalCard? {
        guard let state, let updatedAt else { return nil }
        let arrival = TripMapArrival.Check(state, myParticipantID: myParticipantID, at: updatedAt)
        guard arrival.hasArrived else { return nil }
        return arrival.everyoneHasArrived ? .everyoneArrived : .waitingForEveryone
    }

    /// The tapped car, while it is still in the trip with a position on the map.
    func SelectedCar() -> Participant? {
        guard let selectedCarID else { return nil }
        return state?.participants.first { $0.id == selectedCarID && $0.coordinate != nil }
    }
}
