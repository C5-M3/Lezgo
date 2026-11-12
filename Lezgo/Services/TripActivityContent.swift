//
//  TripActivityContent.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Foundation

/// Turns what the trip map shows into the trip's Live Activity (ADR 0027).
///
/// The activity shows only the current leg, the part of the route from the last stop (or the start) to the next
/// stop, and moves on when the leader passes a stop. Pure, so every rule is unit tested;
/// `TripMapViewModel.activitySnapshot` gathers the input. Texts are localized here, so the extension only draws them.
enum TripActivityContent {
    /// The trip map values the Live Activity is made from.
    struct Input {
        var guidance: TripMapGuidance?
        var cars: [TripMapCarPin]
        /// The group's whole route, start to destination, to measure the leg and place the cars on it.
        var route: [Coordinate]
        /// Every waypoint of the trip, start point and destination included.
        var waypoints: [Waypoint]
        /// The waypoint the group is driving to (`Trip.currentWaypointIndex`).
        var currentWaypointIndex: Int
        var arrivalCard: TripMapViewModel.ArrivalCard?
        var arrivalProgress: TripMapArrivalProgress?
    }

    static func Attributes(destinationName: String) -> TripActivityAttributes {
        TripActivityAttributes(title: String(localized: .tripMapToDestination(destinationName)))
    }

    static func State(_ input: Input) -> TripActivityAttributes.ContentState {
        let road = Road(input.route)
        let leg = CurrentLeg(input)
        let robots = Robots(input, leg: leg, on: road)
        let stage: TripActivityAttributes.Stage = input.arrivalCard != nil ? .arrived
            : input.guidance == nil ? .loading : .driving
        let timeToStop = stage == .driving
            ? input.guidance.map { TimeToStop($0, input: input, leg: leg, on: road) }
            : nil
        return TripActivityAttributes.ContentState(
            stage: stage,
            title: Title(input, leg: leg),
            timeText: timeToStop?.formatted(TripMapCarStatus.durationStyle),
            shortTimeText: timeToStop.map(ShortTime),
            countText: stage == .arrived ? input.arrivalProgress?.countText : nil,
            legStartLabel: LegStartLabel(input, leg: leg),
            legEndLabel: LegEndLabel(leg),
            robots: robots,
            reached: robots.map(\.progress).max() ?? 0,
            myColor: input.cars.first { $0.isMe }.map { RobotColor($0.carColor) } ?? .yellow
        )
    }

    /// The part of the route being driven: from the last waypoint passed to the next one.
    private struct Leg {
        var from: Waypoint?
        var to: Waypoint?
        /// 1 for the first checkpoint; `nil` when the leg ends at the destination.
        var stopNumber: Int?
        var stopCount: Int
    }

    private static func CurrentLeg(_ input: Input) -> Leg {
        let ordered = input.waypoints.sorted { $0.orderIndex < $1.orderIndex }
        let next = ordered.first { $0.orderIndex >= input.currentWaypointIndex && $0.kind != .start } ?? ordered.last
        let previous = ordered.last { $0.orderIndex < (next?.orderIndex ?? 0) }
        let checkpoints = ordered.filter { $0.kind == .checkpoint }
        let number = checkpoints.firstIndex { $0.id == next?.id }.map { $0 + 1 }
        return Leg(from: previous, to: next, stopNumber: number, stopCount: checkpoints.count)
    }

    private static func Title(_ input: Input, leg: Leg) -> String {
        if let card = input.arrivalCard { return String(localized: card.title) }
        return String(localized: .tripMapToDestination(leg.to?.name ?? ""))
    }

    private static func LegStartLabel(_ input: Input, leg: Leg) -> String {
        if let card = input.arrivalCard {
            let isLeader = input.cars.first { $0.isMe }?.isLeader ?? false
            return card.Subtitle(isLeader: isLeader).map { String(localized: $0) } ?? ""
        }
        guard let from = leg.from, from.kind != .start else { return String(localized: .tripActivityStart) }
        return from.name
    }

    private static func LegEndLabel(_ leg: Leg) -> String {
        guard let number = leg.stopNumber else { return String(localized: .tripActivityDestination) }
        return String(localized: .tripActivityStopOfTotal(number, leg.stopCount))
    }

    /// The routing service only knows the time to the destination, so the time to a stop is that time's share for
    /// the part of the road up to the stop.
    private static func TimeToStop(_ guidance: TripMapGuidance, input: Input, leg: Leg, on road: Road) -> Duration {
        guard leg.stopNumber != nil, let stop = leg.to, let me = input.cars.first(where: { $0.isMe }) else {
            return guidance.timeLeft
        }
        let myPlace = road.Along(me.coordinate)
        let toStop = road.Along(stop.coordinate) - myPlace
        let toEnd = road.length - myPlace
        guard toEnd > 0 else { return guidance.timeLeft }
        let share = min(max(toStop / toEnd, 0), 1)
        let seconds = Double(guidance.timeLeft.components.seconds) * share
        return .seconds((seconds / 60).rounded(.up) * 60)
    }

    /// "33 min" within the hour, "1:20" above, so it fits beside the camera.
    private static func ShortTime(_ time: Duration) -> String {
        time < .seconds(3_600)
            ? time.formatted(TripMapCarStatus.durationStyle)
            : time.formatted(.time(pattern: .hourMinute))
    }

    /// Every car at its place along the leg; this phone's car and the leader stay when there are too many.
    private static func Robots(_ input: Input, leg: Leg, on road: Road) -> [TripActivityAttributes.Robot] {
        let start = leg.from.map { road.Along($0.coordinate) } ?? 0
        let end = leg.to.map { road.Along($0.coordinate) } ?? road.length
        let length = end - start
        let ordered = input.cars.filter { $0.isMe || $0.isLeader }
            + input.cars.filter { $0.isMe == false && $0.isLeader == false }
        return ordered.prefix(TripActivityAttributes.maxRobots).map { car in
            let progress = length > 0 ? (road.Along(car.coordinate) - start) / length : 0
            return TripActivityAttributes.Robot(
                id: car.id,
                color: RobotColor(car.carColor),
                progress: input.arrivalCard != nil && car.isMe ? 1 : min(max(progress, 0), 1),
                isMe: car.isMe,
                isOnline: car.isOffline == false
            )
        }
        .sorted { $0.progress < $1.progress }
    }

    private static func RobotColor(_ color: TripMapCarPin.CarColor) -> TripActivityAttributes.RobotColor {
        switch color {
        case .yellow: .yellow
        case .purple: .purple
        case .pink: .pink
        case .blue: .blue
        case .green: .green
        }
    }

    /// The route, to measure how far along it a point is.
    private struct Road {
        let polyline: [Coordinate]
        let length: Double

        init(_ polyline: [Coordinate]) {
            self.polyline = polyline
            length = polyline.last.flatMap { RoutePosition.Locate($0, on: polyline)?.distanceAlongRoute } ?? 0
        }

        /// Metres from the start of the route to the point on it nearest `point`.
        func Along(_ point: Coordinate) -> Double {
            RoutePosition.Locate(point, on: polyline)?.distanceAlongRoute ?? 0
        }
    }
}
