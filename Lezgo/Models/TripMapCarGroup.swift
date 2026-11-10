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

    /// The most robots a closed card shows; the rest are counted, so the card never covers the map around it.
    static let maxRobots = 4

    /// Whether the card has cars it does not show, so tapping the count opens it.
    var canOpen: Bool { pins.count > Self.maxRobots }

    /// The robots on the card: the leader first so its crown is always in sight, then this phone's own car so the
    /// driver finds "You", then the cars with an alert so their warning shows. A closed card shows `maxRobots`; a
    /// tapped car it would hide takes the last place, so its glow shows too.
    func ShownPins(isOpen: Bool, selectedID: UUID? = nil) -> [TripMapCarPin] {
        let ordered = pins.sorted { Priority(of: $0) < Priority(of: $1) }
        guard isOpen == false else { return ordered }
        let shown = Array(ordered.prefix(Self.maxRobots))
        guard let selected = ordered.dropFirst(Self.maxRobots).first(where: { $0.id == selectedID }) else {
            return shown
        }
        return shown.dropLast() + [selected]
    }

    /// Lower comes first on the card. `sorted` keeps the join order among cars of the same priority.
    private func Priority(of pin: TripMapCarPin) -> Int {
        if pin.isLeader { return 0 }
        if pin.isMe { return 1 }
        return pin.isAlerting ? 2 : 3
    }

    /// How many cars the card counts instead of showing.
    func HiddenCount(isOpen: Bool) -> Int {
        isOpen ? 0 : max(pins.count - Self.maxRobots, 0)
    }

    /// Groups cars that are within `metres` of each other, directly or through a car between them.
    ///
    /// Every car can join a group, this phone's own one and those with an alert included: on their own they would
    /// cover the cars under them. The card labels this phone's car "You" and keeps each car's badge, so neither gets
    /// lost. A tapped car stays on its card and glows there, so the card does not jump while its status is open.
    static func Make(pins: [TripMapCarPin], within metres: Double) -> [TripMapCarGroup] {
        var groups: [[TripMapCarPin]] = []
        for pin in pins {
            let isClose = { (group: [TripMapCarPin]) in
                group.contains { other in
                    other.coordinate.Distance(to: pin.coordinate) <= metres
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
