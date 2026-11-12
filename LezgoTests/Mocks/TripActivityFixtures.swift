//
//  TripActivityFixtures.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Foundation
@testable import Lezgo

/// The US-06 trip as the Live Activity sees it: leader Agus at the first checkpoint, Budi (this phone) at the start
/// and Citra a quarter of the way, with two checkpoints before Pakuwon mall.
@MainActor
enum TripActivityFixtures {
    typealias Fixtures = TripMapFixtures

    static let route = [
        Fixtures.startPoint.coordinate, Fixtures.checkpoint.coordinate, Fixtures.destination.coordinate
    ]
    /// A second checkpoint half way along the second leg, about three quarters along the route.
    static let secondCheckpoint = Waypoint(
        id: UUID(), tripID: Fixtures.tripID, orderIndex: 2, kind: .checkpoint, name: "Rest area KM 57",
        coordinate: Coordinate(latitude: -7.2908, longitude: 112.6978)
    )
    static var lastStop: Waypoint {
        var destination = Fixtures.destination
        destination.orderIndex = 3
        return destination
    }
    static let waypoints = [Fixtures.startPoint, Fixtures.checkpoint, secondCheckpoint, lastStop]
    /// Half way along the first leg, about a quarter along the route.
    static let quarterWay = Coordinate(latitude: -7.27715, longitude: 112.7285)

    static func Pin(
        _ id: UUID,
        _ name: String,
        at coordinate: Coordinate,
        color: TripMapCarPin.CarColor,
        isLeader: Bool = false,
        isMe: Bool = false,
        isOffline: Bool = false
    ) -> TripMapCarPin {
        TripMapCarPin(
            id: id,
            displayName: name,
            coordinate: coordinate,
            motionState: .driving,
            isLeader: isLeader,
            isMe: isMe,
            isOffline: isOffline,
            carColor: color
        )
    }

    static let agus = Pin(Fixtures.agusID, "Agus", at: Fixtures.checkpoint.coordinate, color: .yellow, isLeader: true)
    static let budi = Pin(Fixtures.budiID, "Budi", at: Fixtures.startPoint.coordinate, color: .blue, isMe: true)
    static let citra = Pin(Fixtures.citraID, "Citra", at: quarterWay, color: .pink)

    static func Input(
        guidance: TripMapGuidance? = Fixtures.Guidance(minutesLeft: 80),
        cars: [TripMapCarPin] = [agus, budi, citra],
        waypoints: [Waypoint] = waypoints,
        currentWaypointIndex: Int = 1,
        arrivalCard: TripMapViewModel.ArrivalCard? = nil,
        arrivalProgress: TripMapArrivalProgress? = nil
    ) -> TripActivityContent.Input {
        TripActivityContent.Input(
            guidance: guidance,
            cars: cars,
            route: route,
            waypoints: waypoints,
            currentWaypointIndex: currentWaypointIndex,
            arrivalCard: arrivalCard,
            arrivalProgress: arrivalProgress
        )
    }
}
