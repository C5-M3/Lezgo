//
//  TripActivityContent.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Foundation

/// Turns what the trip map shows into the trip's Live Activity (ADR 0027).
///
/// Pure, so every rule is unit tested; `TripMapViewModel.activitySnapshot` gathers the input. Texts are localized
/// here, in the app, so the widget extension only draws them.
enum TripActivityContent {
    /// The trip map values the Live Activity is made from.
    struct Input {
        var destinationName: String
        var guidance: TripMapGuidance?
        var isRerouting: Bool
        var cars: [TripMapCarPin]
        /// The group's whole route, start to destination, to place the robots and stops along it.
        var route: [Coordinate]
        /// Every waypoint of the trip, start point and destination included.
        var waypoints: [Waypoint]
        var currentWaypointIndex: Int
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
        let road = Road(input.route)
        let me = input.cars.first { $0.isMe }
        let myColor = me.map { RobotColor($0.carColor) } ?? .yellow
        let isLeader = me?.isLeader ?? false
        let stage = Stage(input)
        let timeLeft = stage == .arrived ? nil : input.guidance?.timeLeft
        let onRoute = input.cars.filter { $0.isAlerting == false && $0.isOffline == false }.count
        return TripActivityAttributes.ContentState(
            stage: stage,
            turn: stage == .driving ? input.guidance.map(Turn) : nil,
            headline: Headline(input, stage: stage),
            statusText: stage == .rerouting ? String(localized: .tripMapRerouting) : nil,
            timeLeftText: timeLeft?.formatted(TripMapCarStatus.durationStyle),
            shortTimeLeftText: timeLeft.map(ShortTime),
            arrivalTimeText: timeLeft.map { ArrivalTime($0, now: input.now) },
            detailText: stage == .arrived ? nil : input.guidance.map { Detail($0, now: input.now) },
            groupText: isLeader
                ? String(localized: .tripActivityCarsOnRoute(onRoute, input.cars.count))
                : String(localized: .tripActivityFollowing(input.cars.first { $0.isLeader }?.displayName ?? "")),
            isGroupWarning: isLeader && onRoute < input.cars.count,
            alert: input.alertBanner.map { Alert($0, cars: input.cars, myColor: myColor, road: road) },
            arrival: Arrival(input),
            robots: Robots(input.cars, on: road),
            stops: Stops(input, on: road),
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
            distanceText: Distance(guidance.distanceToTurn),
            instruction: guidance.instruction
        )
    }

    /// The next checkpoint while one is left, then the destination.
    private static func Headline(_ input: Input, stage: TripActivityAttributes.Stage) -> String {
        if stage == .arrived { return input.destinationName }
        let nextStop = input.waypoints
            .sorted { $0.orderIndex < $1.orderIndex }
            .first { $0.kind == .checkpoint && $0.IsVisited(currentWaypointIndex: input.currentWaypointIndex) == false }
        guard let nextStop else { return String(localized: .tripMapToDestination(input.destinationName)) }
        return String(localized: .tripActivityNextStop(nextStop.name))
    }

    /// "33 min" within the hour, "1:20" above, so it fits beside the camera.
    private static func ShortTime(_ timeLeft: Duration) -> String {
        timeLeft < .seconds(3_600)
            ? timeLeft.formatted(TripMapCarStatus.durationStyle)
            : timeLeft.formatted(.time(pattern: .hourMinute))
    }

    private static func ArrivalTime(_ timeLeft: Duration, now: Date) -> String {
        now.addingTimeInterval(TimeInterval(timeLeft.components.seconds)).formatted(date: .omitted, time: .shortened)
    }

    /// "64 km · Arrive 11:01", or only the arrival time when the distance left is unknown.
    private static func Detail(_ guidance: TripMapGuidance, now: Date) -> String {
        let arrive = String(localized: .tripMapArriveAt(ArrivalTime(guidance.timeLeft, now: now)))
        guard let distanceLeft = guidance.distanceLeft else { return arrive }
        return String(localized: .tripActivityDistanceAndArrival(Distance(distanceLeft), arrive))
    }

    private static func Distance(_ distance: Measurement<UnitLength>) -> String {
        distance.formatted(.measurement(width: .abbreviated, usage: .road))
    }

    private static func Alert(
        _ banner: TripMapAlerts.Banner,
        cars: [TripMapCarPin],
        myColor: TripActivityAttributes.RobotColor,
        road: Road
    ) -> TripActivityAttributes.Alert {
        let text = String(localized: banner.message)
        switch banner {
        case let .mine(alert):
            return TripActivityAttributes.Alert(
                text: text,
                shortText: ShortText(alert),
                detail: nil,
                color: myColor,
                carName: String(localized: .tripMapCarYou)
            )
        case let .otherCar(id, name, alert):
            let car = cars.first { $0.id == id }
            return TripActivityAttributes.Alert(
                text: text,
                shortText: ShortText(alert),
                detail: Gap(to: car, from: cars.first { $0.isMe }, on: road),
                color: car.map { RobotColor($0.carColor) } ?? .yellow,
                carName: name
            )
        case let .carStopped(id, name):
            let car = cars.first { $0.id == id }
            return TripActivityAttributes.Alert(
                text: text,
                shortText: String(localized: .tripActivityShortStopped),
                detail: Gap(to: car, from: cars.first { $0.isMe }, on: road),
                color: car.map { RobotColor($0.carColor) } ?? .yellow,
                carName: name
            )
        }
    }

    private static func ShortText(_ alert: FormationAlert) -> String {
        switch alert {
        case .none, .offRoute: String(localized: .tripActivityShortOffRoute)
        case .aheadOfLeader: String(localized: .tripActivityShortAhead)
        case .passedCheckpoint: String(localized: .tripActivityShortMissedStop)
        case .passedDestination: String(localized: .tripActivityShortPassed)
        }
    }

    /// "400 m behind you" or "2 km ahead of you", measured along the route.
    private static func Gap(to car: TripMapCarPin?, from me: TripMapCarPin?, on road: Road) -> String? {
        guard let car, let me, road.length > 0 else { return nil }
        let metres = road.Along(car.coordinate) - road.Along(me.coordinate)
        let distance = Distance(Measurement(value: abs(metres), unit: .meters))
        return String(localized: metres < 0 ? .tripActivityBehindYou(distance) : .tripActivityAheadOfYou(distance))
    }

    private static func Arrival(_ input: Input) -> TripActivityAttributes.Arrival? {
        guard let card = input.arrivalCard else { return nil }
        let isLeader = input.cars.first { $0.isMe }?.isLeader ?? false
        return TripActivityAttributes.Arrival(
            title: String(localized: card.title),
            countText: input.arrivalProgress?.countText ?? "",
            detail: card.Subtitle(isLeader: isLeader).map { String(localized: $0) }
        )
    }

    /// Every checkpoint at its place along the route, numbered from 1.
    private static func Stops(_ input: Input, on road: Road) -> [TripActivityAttributes.Stop] {
        input.waypoints
            .filter { $0.kind == .checkpoint }
            .sorted { $0.orderIndex < $1.orderIndex }
            .enumerated()
            .map { index, checkpoint in
                TripActivityAttributes.Stop(
                    number: index + 1,
                    progress: road.Progress(of: checkpoint.coordinate),
                    isVisited: checkpoint.IsVisited(currentWaypointIndex: input.currentWaypointIndex)
                )
            }
    }

    /// Every car at its place along the route. Cars close together share one robot, which shows this phone's car
    /// first, then the leader; a car with an alert always keeps its own robot, so the driver sees which one it is.
    /// With more groups than fit, this phone's car and the leader stay.
    private static func Robots(_ cars: [TripMapCarPin], on road: Road) -> [TripActivityAttributes.Robot] {
        let robots = cars
            .map { car in
                TripActivityAttributes.Robot(
                    id: car.id,
                    color: RobotColor(car.carColor),
                    progress: road.Progress(of: car.coordinate),
                    isMe: car.isMe,
                    isLeader: car.isLeader,
                    isAlerting: car.isAlerting
                )
            }
            .sorted { $0.progress < $1.progress }
        var groups: [TripActivityAttributes.Robot] = []
        for robot in robots {
            guard robot.isAlerting == false,
                  let index = groups.lastIndex(where: { $0.isAlerting == false }),
                  robot.progress - groups[index].progress < TripActivityAttributes.groupDistance else {
                groups.append(robot)
                continue
            }
            let last = groups[index]
            var group = Priority(robot) > Priority(last) ? robot : last
            group.groupCount = last.groupCount + 1
            groups[index] = group
        }
        let kept = groups.filter { $0.isMe || $0.isLeader } + groups.filter { $0.isMe == false && $0.isLeader == false }
        return Array(kept.prefix(TripActivityAttributes.maxRobots)).sorted { $0.progress < $1.progress }
    }

    private static func Priority(_ robot: TripActivityAttributes.Robot) -> Int {
        if robot.isMe { return 2 }
        return robot.isLeader ? 1 : 0
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

        /// 0 at the start, 1 at the destination.
        func Progress(of point: Coordinate) -> Double {
            length > 0 ? min(max(Along(point) / length, 0), 1) : 0
        }
    }
}
