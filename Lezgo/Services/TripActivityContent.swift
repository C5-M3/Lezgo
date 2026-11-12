//
//  TripActivityContent.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Foundation

/// Turns what the trip map shows into the trip's Live Activity (ADR 0027).
///
/// Pure, so every rule is unit tested; `TripMapViewModel.activityInput` gathers the input. Texts are localized here,
/// in the app, so the widget extension only draws them.
enum TripActivityContent {
    /// The trip map values the Live Activity is made from.
    struct Input {
        var guidance: TripMapGuidance?
        var isRerouting: Bool
        var cars: [TripMapCarPin]
        /// The group's whole route, start to destination, to place the robots along it.
        var route: [Coordinate]
        var upcomingWaypoints: [Waypoint]
        var alertBanner: TripMapAlerts.Banner?
        var arrivalCard: TripMapViewModel.ArrivalCard?
        var arrivalProgress: TripMapArrivalProgress?
        var isMuted: Bool
        var now: Date
    }

    static func Attributes(destinationName: String) -> TripActivityAttributes {
        TripActivityAttributes(title: String(localized: .tripMapToDestination(destinationName)))
    }

    static func State(_ input: Input) -> TripActivityAttributes.ContentState {
        let me = input.cars.first { $0.isMe }
        let myColor = me.map { RobotColor($0.carColor) } ?? .yellow
        let isLeader = me?.isLeader ?? false
        let stage = Stage(input)
        let guidance = stage == .driving ? input.guidance : nil
        let onRoute = input.cars.filter { $0.isAlerting == false && $0.isOffline == false }.count
        let timeLeft = stage == .arrived ? nil : input.guidance?.timeLeft
        return TripActivityAttributes.ContentState(
            stage: stage,
            turn: guidance.map(Turn),
            timeLeftText: timeLeft?.formatted(TripMapCarStatus.durationStyle),
            shortTimeLeftText: timeLeft?.formatted(.time(pattern: .hourMinute)),
            detailText: stage == .arrived ? nil : input.guidance.map { Detail($0, now: input.now) },
            nextStopText: NextStop(input.upcomingWaypoints),
            groupText: isLeader
                ? String(localized: .tripActivityCarsOnRoute(onRoute, input.cars.count))
                : String(localized: .tripActivityFollowing(input.cars.first { $0.isLeader }?.displayName ?? "")),
            isGroupWarning: isLeader && onRoute < input.cars.count,
            alert: input.alertBanner.map { Alert($0, cars: input.cars, myColor: myColor) },
            arrival: Arrival(input),
            robots: Robots(input.cars, on: input.route),
            myColor: myColor,
            isLeader: isLeader,
            isMuted: input.isMuted,
            muteLabel: String(localized: input.isMuted ? .tripMapUnmute : .tripMapMute)
        )
    }

    private static func Stage(_ input: Input) -> TripActivityAttributes.Stage {
        if input.arrivalCard != nil { return .arrived }
        if input.isRerouting { return .rerouting }
        return input.guidance == nil ? .loading : .driving
    }

    private static func Turn(_ guidance: TripMapGuidance) -> TripActivityAttributes.Turn {
        TripActivityAttributes.Turn(
            symbolName: guidance.direction.symbolName,
            distanceText: guidance.distanceToTurn.formatted(.measurement(width: .abbreviated, usage: .road)),
            instruction: guidance.instruction
        )
    }

    /// "64 km · Arrive 11:01", or only the arrival time when the distance left is unknown.
    private static func Detail(_ guidance: TripMapGuidance, now: Date) -> String {
        let arrivalTime = now.addingTimeInterval(TimeInterval(guidance.timeLeft.components.seconds))
        let arrive = String(localized: .tripMapArriveAt(arrivalTime.formatted(date: .omitted, time: .shortened)))
        guard let distanceLeft = guidance.distanceLeft else { return arrive }
        let distance = distanceLeft.formatted(.measurement(width: .abbreviated, usage: .road))
        return String(localized: .tripActivityDistanceAndArrival(distance, arrive))
    }

    private static func NextStop(_ waypoints: [Waypoint]) -> String? {
        guard let checkpoint = waypoints.first(where: { $0.kind == .checkpoint }) else { return nil }
        return String(localized: .tripActivityNextStop(checkpoint.name))
    }

    private static func Alert(
        _ banner: TripMapAlerts.Banner,
        cars: [TripMapCarPin],
        myColor: TripActivityAttributes.RobotColor
    ) -> TripActivityAttributes.Alert {
        let text = String(localized: banner.message)
        switch banner {
        case .mine:
            return TripActivityAttributes.Alert(text: text, color: myColor, carName: String(localized: .tripMapCarYou))
        case let .otherCar(id, name, _), let .carStopped(id, name):
            let color = cars.first { $0.id == id }.map { RobotColor($0.carColor) } ?? .yellow
            return TripActivityAttributes.Alert(text: text, color: color, carName: name)
        }
    }

    private static func Arrival(_ input: Input) -> TripActivityAttributes.Arrival? {
        guard let card = input.arrivalCard else { return nil }
        return TripActivityAttributes.Arrival(
            title: String(localized: card.title),
            countText: input.arrivalProgress?.countText ?? ""
        )
    }

    /// Every car at its place along the route. With more cars than fit, this phone's car and the leader stay.
    private static func Robots(_ cars: [TripMapCarPin], on route: [Coordinate]) -> [TripActivityAttributes.Robot] {
        let length = route.last.flatMap { RoutePosition.Locate($0, on: route)?.distanceAlongRoute } ?? 0
        let ordered = cars.filter { $0.isMe || $0.isLeader } + cars.filter { $0.isMe == false && $0.isLeader == false }
        return ordered.prefix(TripActivityAttributes.maxRobots).map { car in
            let along = RoutePosition.Locate(car.coordinate, on: route)?.distanceAlongRoute ?? 0
            return TripActivityAttributes.Robot(
                id: car.id,
                color: RobotColor(car.carColor),
                progress: length > 0 ? min(max(along / length, 0), 1) : 0,
                isMe: car.isMe,
                isLeader: car.isLeader,
                isAlerting: car.isAlerting
            )
        }
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
}
