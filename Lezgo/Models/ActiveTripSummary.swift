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
    var startCoordinate: Coordinate?
    var destinationCoordinate: Coordinate?
    var routeCoordinates: [Coordinate]?
    var estimatedDuration: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case tripID
        case myParticipantID
        case roomCode
        case startName
        case destinationName
        case distanceText
        case memberNames
        case status
        case isLeader
        case startCoordinate
        case destinationCoordinate
        case routeCoordinates
        case estimatedDuration
    }

    init(
        tripID: UUID,
        myParticipantID: UUID,
        roomCode: String,
        startName: String,
        destinationName: String,
        distanceText: String? = nil,
        memberNames: [String] = [],
        status: TripStatus = .lobby,
        isLeader: Bool = false,
        startCoordinate: Coordinate? = nil,
        destinationCoordinate: Coordinate? = nil,
        routeCoordinates: [Coordinate]? = nil,
        estimatedDuration: TimeInterval? = nil
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
        self.startCoordinate = startCoordinate
        self.destinationCoordinate = destinationCoordinate
        self.routeCoordinates = routeCoordinates
        self.estimatedDuration = estimatedDuration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tripID = try container.decode(UUID.self, forKey: .tripID)
        myParticipantID = try container.decode(UUID.self, forKey: .myParticipantID)
        roomCode = try container.decode(String.self, forKey: .roomCode)
        startName = try container.decode(String.self, forKey: .startName)
        destinationName = try container.decode(String.self, forKey: .destinationName)
        distanceText = try container.decodeIfPresent(String.self, forKey: .distanceText)
        memberNames = (try? container.decode([String].self, forKey: .memberNames)) ?? []
        status = (try? container.decode(TripStatus.self, forKey: .status)) ?? .lobby
        isLeader = (try? container.decode(Bool.self, forKey: .isLeader)) ?? false
        startCoordinate = try container.decodeIfPresent(Coordinate.self, forKey: .startCoordinate)
        destinationCoordinate = try container.decodeIfPresent(Coordinate.self, forKey: .destinationCoordinate)
        routeCoordinates = try container.decodeIfPresent([Coordinate].self, forKey: .routeCoordinates)
        estimatedDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .estimatedDuration)
    }

    /// Creates an active trip summary from a live or simulated trip session.
    static func From(
        session: TripSession,
        distanceText: String? = nil,
        estimatedDuration: TimeInterval? = nil
    ) -> ActiveTripSummary {
        let isLeader = session.state.trip.leaderParticipantID == session.myParticipantID
        let startWaypoint = session.state.waypoints.first(where: { $0.kind == .start })
        let start = startWaypoint?.name ?? "Start Point"
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
            isLeader: isLeader,
            startCoordinate: startWaypoint?.coordinate,
            destinationCoordinate: session.state.destination?.coordinate,
            routeCoordinates: session.state.route?.polyline,
            estimatedDuration: estimatedDuration
        )
    }
}
