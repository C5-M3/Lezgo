//
//  TripMapCarGroup.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 05/11/26.
//

import Foundation

/// One spot on the trip map: a car on its own, or cars so close together that their robots would overlap.
struct TripMapCarGroup: Identifiable, Hashable {
    /// The first car's ID, so the group stays the same one while its cars move.
    var id: UUID { pins[0].id }
    /// Never empty.
    let pins: [TripMapCarPin]

    /// The point between the cars.
    var coordinate: Coordinate {
        Coordinate(
            latitude: pins.map(\.coordinate.latitude).reduce(0, +) / Double(pins.count),
            longitude: pins.map(\.coordinate.longitude).reduce(0, +) / Double(pins.count)
        )
    }

    /// Groups cars that are within `metres` of each other, directly or through a car between them.
    ///
    /// A car with an alert and the tapped car stay on their own, so their warning and glow still show. To reach a car
    /// in a group, tap its robot: it then stands on its own.
    static func Make(pins: [TripMapCarPin], selectedID: UUID?, within metres: Double) -> [TripMapCarGroup] {
        var groups: [[TripMapCarPin]] = []
        for pin in pins {
            guard pin.isAlerting == false, pin.id != selectedID else {
                groups.append([pin])
                continue
            }
            let isClose = { (group: [TripMapCarPin]) in
                group.contains { other in
                    other.isAlerting == false && other.id != selectedID
                        && other.coordinate.Distance(to: pin.coordinate) <= metres
                }
            }
            let joined = groups.filter(isClose).flatMap { $0 } + [pin]
            guard let first = groups.firstIndex(where: isClose) else {
                groups.append([pin])
                continue
            }
            groups[first] = joined
            groups = groups.enumerated().filter { $0.offset == first || isClose($0.element) == false }.map(\.element)
        }
        return groups.map(TripMapCarGroup.init)
    }
}
