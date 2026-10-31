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

    /// The route from this phone's car on.
    var routeAhead: [Coordinate] {
        []
    }

    /// The stops still ahead.
    var upcomingWaypoints: [Waypoint] {
        []
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

    /// A pin for every car that has sent a position; members without one yet have no pin.
    var carPins: [TripMapCarPin] {
        guard let state, let updatedAt else { return [] }
        return state.participants.compactMap { participant in
            guard let coordinate = participant.coordinate else { return nil }
            // The location dot already shows this phone's car.
            if showsMyLocationDot, participant.id == myParticipantID { return nil }
            return TripMapCarPin(
                id: participant.id,
                displayName: participant.displayName,
                coordinate: coordinate,
                motionState: participant.motionState,
                course: participant.course,
                isLeader: participant.IsLeader(in: state.trip),
                isMe: participant.id == myParticipantID,
                isOffline: participant.IsOnline(at: updatedAt) == false,
                isAlerting: alerts.IsShared(participant, in: state, at: updatedAt)
            )
        }
    }

    /// The status card of the tapped car, or `nil` while no car is tapped.
    ///
    /// The street and time left appear once they are looked up; an offline car shows when it was last seen instead.
    var selectedCarStatus: TripMapCarStatus? {
        SelectedCar().flatMap(CarStatus)
    }

    /// Every car in the trip for the pulled-up sheet, the leader first and then in the order they joined. Cars
    /// without a position yet are listed too: they are in the trip, only not on the map.
    var carStatuses: [TripMapCarStatus] {
        guard let state else { return [] }
        let leaders = state.participants.filter { $0.IsLeader(in: state.trip) }
        let members = state.participants.filter { $0.IsLeader(in: state.trip) == false }
        return (leaders + members).compactMap(CarStatus)
    }

    /// The 6-digit code others type to join, shown in the sheet so a late car can still join on the road.
    var roomCode: String? {
        state?.trip.roomCode
    }

    /// What a car is doing, with the street and time left once they are looked up for it.
    private func CarStatus(of car: Participant) -> TripMapCarStatus? {
        guard let state, let updatedAt else { return nil }
        let isLeader = car.IsLeader(in: state.trip)
        let isMe = car.id == myParticipantID
        guard car.IsOnline(at: updatedAt) else {
            let lastSeen = Duration.seconds(updatedAt.timeIntervalSince(car.lastSeenAt))
            return TripMapCarStatus(
                id: car.id,
                displayName: car.displayName,
                activity: .offline(lastSeen: lastSeen),
                isLeader: isLeader,
                isMe: isMe
            )
        }
        let lookup = carLookups[car.id]
        let activity: TripMapCarStatus.Activity = car.motionState == .driving
            ? .driving(street: lookup?.street)
            : .stopped(street: lookup?.street)
        return TripMapCarStatus(
            id: car.id,
            displayName: car.displayName,
            activity: activity,
            timeLeft: lookup?.timeLeft,
            isLeader: isLeader,
            isMe: isMe
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

    /// Whether the leader has already moved the trip past this waypoint.
    func IsVisited(_ waypoint: Waypoint) -> Bool {
        guard let state else { return false }
        return waypoint.IsVisited(currentWaypointIndex: state.trip.currentWaypointIndex)
    }
}
