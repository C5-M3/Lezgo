//
//  ActiveTripSummary.swift
//  Lezgo
//
//  Created by Rizal Pratama on 27/10/26.
//

import Foundation

/// A device-saved summary of an active or draft trip (US-03).
///
/// Enables the app to instantly show "You have a trip in progress" with the start point,
/// destination, distance, and participants, without blocking on remote network fetch.
struct ActiveTripSummary: Codable, Hashable, Sendable {
    var tripID: UUID
    var myParticipantID: UUID
    var roomCode: String
    var startName: String
    var destinationName: String
    var distanceText: String?
    var memberNames: [String]
    var status: TripStatus
    var isLeader: Bool

    init(
        tripID: UUID,
        myParticipantID: UUID,
        roomCode: String,
        startName: String,
        destinationName: String,
        distanceText: String? = nil,
        memberNames: [String] = [],
        status: TripStatus = .lobby,
        isLeader: Bool = false
    ) {
        self.tripID = tripID
        self.myParticipantID = myParticipantID
        self.roomCode = roomCode
        self.startName = startName
        self.destinationName = destinationName
        self.distanceText = distanceText
        self.memberNames = memberNames
        self.status = status
        self.isLeader = isLeader
    }

    /// Creates an active trip summary from a live or simulated trip session.
    static func From(session: TripSession, distanceText: String? = nil) -> ActiveTripSummary {
        let isLeader = session.state.trip.leaderParticipantID == session.myParticipantID
        let start = session.state.waypoints.first(where: { $0.kind == .start })?.name ?? "Start Point"
        let destination = session.state.destination?.name ?? "Destination"
        let memberNames = session.state.participants.map(session.state.DisplayName)

        return ActiveTripSummary(
            tripID: session.state.trip.id,
            myParticipantID: session.myParticipantID,
            roomCode: session.state.trip.roomCode,
            startName: start,
            destinationName: destination,
            distanceText: distanceText,
            memberNames: memberNames,
            status: session.state.trip.status,
            isLeader: isLeader
        )
    }
}
