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

    /// The robots on the card, the leader first so its crown is always in sight. A closed card shows `maxRobots`;
    /// a tapped car it would hide takes the last place, so its glow shows too.
    func ShownPins(isOpen: Bool, selectedID: UUID? = nil) -> [TripMapCarPin] {
        let leaderFirst = pins.filter(\.isLeader) + pins.filter { $0.isLeader == false }
        guard isOpen == false else { return leaderFirst }
        let shown = Array(leaderFirst.prefix(Self.maxRobots))
        guard let selected = leaderFirst.dropFirst(Self.maxRobots).first(where: { $0.id == selectedID }) else {
            return shown
        }
        return shown.dropLast() + [selected]
    }

    /// How many cars the card counts instead of showing.
    func HiddenCount(isOpen: Bool) -> Int {
        isOpen ? 0 : max(pins.count - Self.maxRobots, 0)
    }

    /// Groups cars that are within `metres` of each other, directly or through a car between them.
    ///
    /// A car with an alert stays on its own, so its warning still shows, and so does this phone's own car, so the
    /// driver can always find it. A tapped car stays on its card and glows there, so the card does not jump while its
    /// status is open.
    static func Make(pins: [TripMapCarPin], within metres: Double) -> [TripMapCarGroup] {
        var groups: [[TripMapCarPin]] = []
        for pin in pins {
            guard IsGroupable(pin) else {
                groups.append([pin])
                continue
            }
            let isClose = { (group: [TripMapCarPin]) in
                group.contains { other in
                    IsGroupable(other) && other.coordinate.Distance(to: pin.coordinate) <= metres
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

    private static func IsGroupable(_ pin: TripMapCarPin) -> Bool {
        pin.isAlerting == false && pin.isMe == false
    }
}
