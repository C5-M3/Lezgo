//
//  TripAnswers.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Foundation

/// What Siri says about the trip on the road (`specs/UserStories.md` → US-08, ADR 0030).
///
/// The Siri intents stay thin: they take the open trip map, build one of these from what it shows, and speak the
/// sentence. Every rule and every word lives here, so it is tested like any other logic.
struct TripAnswers {
    /// Closer than this, a car is "right next to you", in metres.
    static let nextToYou = 50.0
    /// Further than this from the group's road, a car is "away" and distances are in a straight line, in metres. The
    /// same distance as a member's off-route alert (US-06).
    static let offRoad = 50.0
    /// Distances under 1 km are rounded to this, in metres: GPS is not more precise than that.
    private static let roundedTo = 10.0

    static var noTrip: String { String(localized: .siriNoTrip) }
    static var arrivalFailed: String { String(localized: .siriArrivalFailed) }

    var state: TripState
    var myParticipantID: UUID
    /// This phone's GPS position; `nil` until the first reading.
    var myCoordinate: Coordinate?
    var guidance: TripMapGuidance?
    /// Street names already looked up, by car.
    var streets: [UUID: String] = [:]
    var now: Date
    /// How numbers are written: "1.2 km" or "1,2 km". Tests fix it so they do not depend on the phone's region.
    var locale = Locale.autoupdatingCurrent

    // MARK: Where a car is

    /// "Where's the leader in Lezgo".
    func WhereIsLeader() -> String {
        guard let leader = state.leader else { return Self.noTrip }
        guard leader.id != myParticipantID else { return String(localized: .siriYouAreTheLeader) }
        return WhereIs(carID: leader.id)
    }

    /// "Where's [name] in Lezgo".
    func WhereIs(carID: UUID) -> String {
        guard carID != myParticipantID else { return String(localized: .siriThatsYou) }
        guard let car = state.participants.first(where: { $0.id == carID }) else {
            return String(localized: .siriCarNotInTrip)
        }
        let name = state.DisplayName(of: car)
        guard car.IsOnline(at: now) else {
            let lastSeen = Duration.seconds(now.timeIntervalSince(car.lastSeenAt))
            return String(localized: .siriCarOffline(name, lastSeen.formatted(TripMapCarStatus.durationStyle)))
        }
        guard let carCoordinate = car.coordinate else { return String(localized: .siriCarLocationUnknown(name)) }
        guard let myCoordinate else { return String(localized: .siriMyLocationUnknown) }
        return Sentence(name: name, gap: MeasureGap(from: myCoordinate, to: carCoordinate), street: streets[carID])
    }

    /// Which way a car is along the group's road; `away` when one of the two cars is off it.
    enum Direction: Hashable { case ahead, behind, away }

    /// How far a car is, and which way along the group's road.
    struct Gap: Hashable {
        var metres: Double
        var direction: Direction
    }

    /// Along the group's road when both cars are on it, otherwise in a straight line.
    func MeasureGap(from me: Coordinate, to car: Coordinate) -> Gap {
        let road = state.groupPath
        if let mine = RoutePosition.Locate(me, on: road), let theirs = RoutePosition.Locate(car, on: road),
           mine.distanceFromRoute <= Self.offRoad, theirs.distanceFromRoute <= Self.offRoad {
            let along = theirs.distanceAlongRoute - mine.distanceAlongRoute
            return Gap(metres: abs(along), direction: along >= 0 ? .ahead : .behind)
        }
        return Gap(metres: me.Distance(to: car), direction: .away)
    }

    /// "1.2 km ahead", under a car's name on a Siri card; `nil` for this phone's own car or without both positions.
    func ShortGap(to carID: UUID) -> String? {
        guard carID != myParticipantID, let myCoordinate,
              let car = state.participants.first(where: { $0.id == carID }), let coordinate = car.coordinate else {
            return nil
        }
        let gap = MeasureGap(from: myCoordinate, to: coordinate)
        guard gap.metres > Self.nextToYou else { return String(localized: .siriShortNextToYou) }
        let distance = Spoken(metres: gap.metres)
        switch gap.direction {
        case .ahead: return String(localized: .siriShortAhead(distance))
        case .behind: return String(localized: .siriShortBehind(distance))
        case .away: return String(localized: .siriShortAway(distance))
        }
    }

    private func Sentence(name: String, gap: Gap, street: String?) -> String {
        guard gap.metres > Self.nextToYou else { return String(localized: .siriCarNextToYou(name)) }
        let distance = Spoken(metres: gap.metres)
        switch (gap.direction, street) {
        case (.ahead, let street?): return String(localized: .siriCarAheadOnStreet(name, distance, street))
        case (.ahead, nil): return String(localized: .siriCarAhead(name, distance))
        case (.behind, let street?): return String(localized: .siriCarBehindOnStreet(name, distance, street))
        case (.behind, nil): return String(localized: .siriCarBehind(name, distance))
        case (.away, let street?): return String(localized: .siriCarAwayOnStreet(name, distance, street))
        case (.away, nil): return String(localized: .siriCarAway(name, distance))
        }
    }

    // MARK: Is everyone with me

    /// "Is everyone with me in Lezgo": how many cars are with the group, then each car that is not, in the order of
    /// the alert banners (US-06), offline cars last.
    func EveryoneWithMe() -> String {
        let cars = state.participants
        guard cars.count > 1 else { return String(localized: .siriOnlyCar) }
        let reasons = cars.compactMap { car in ReasonNotWithGroup(car).map { (car: car, reason: $0) } }
            .sorted { $0.reason.rawValue < $1.reason.rawValue }
        guard reasons.isEmpty == false else { return String(localized: .siriAllWithGroup(cars.count)) }
        let count = String(localized: .siriSomeWithGroup(cars.count - reasons.count, cars.count))
        let details = reasons.map { Sentence(for: $0.car, $0.reason) }
        return ([count] + details).joined(separator: " ")
    }

    /// Why a car is not with the group, in the order the answer names them.
    enum Reason: Int {
        case passedDestination, offRoute, passedCheckpoint, aheadOfLeader, offline
    }

    /// `nil` for a car that is with the group: online (this phone's own car always is) with no formation alert, or
    /// already at the destination.
    func ReasonNotWithGroup(_ car: Participant) -> Reason? {
        if let destination = state.destination, TripMapArrival.IsThere(car, at: destination) { return nil }
        if car.id != myParticipantID, car.IsOnline(at: now) == false { return .offline }
        switch car.alert {
        case .none: return nil
        case .offRoute: return .offRoute
        case .passedCheckpoint: return .passedCheckpoint
        case .passedDestination: return .passedDestination
        case .aheadOfLeader: return .aheadOfLeader
        }
    }

    private func Sentence(for car: Participant, _ reason: Reason) -> String {
        if car.id == myParticipantID, let mine = MySentence(reason) { return mine }
        let name = state.DisplayName(of: car)
        switch reason {
        case .passedDestination: return String(localized: .siriCarPassedDestination(name))
        case .offRoute: return String(localized: .siriCarOffRoute(name))
        case .passedCheckpoint: return String(localized: .siriCarPassedCheckpoint(name))
        case .aheadOfLeader: return String(localized: .siriCarAheadOfLeader(name))
        case .offline: return String(localized: .siriCarIsOffline(name))
        }
    }

    /// The same reason about this phone's own car, which is never offline to itself.
    private func MySentence(_ reason: Reason) -> String? {
        switch reason {
        case .passedDestination: String(localized: .siriYouPassedDestination)
        case .offRoute: String(localized: .siriYouOffRoute)
        case .passedCheckpoint: String(localized: .siriYouPassedCheckpoint)
        case .aheadOfLeader: String(localized: .siriYouAheadOfLeader)
        case .offline: nil
        }
    }

    // MARK: How long left

    /// "How long left in Lezgo": the time and distance to the destination, then the next unvisited checkpoint.
    func TimeLeft() -> String {
        guard let guidance, let destination = state.destination else {
            return String(localized: .siriTimeLeftUnknown)
        }
        let time = guidance.timeLeft.formatted(TripMapCarStatus.durationStyle)
        let distance = guidance.distanceLeft.map { Spoken(metres: $0.converted(to: .meters).value) }
        var sentences = [
            distance.map { String(localized: .siriTimeLeft(time, destination.name, $0)) }
                ?? String(localized: .siriTimeLeftNoDistance(time, destination.name))
        ]
        if let checkpoint = state.nextCheckpoint, let metres = DistanceAlongRoad(to: checkpoint.coordinate) {
            sentences.append(String(localized: .siriNextStop(checkpoint.name, Spoken(metres: metres))))
        }
        return sentences.joined(separator: " ")
    }

    /// How far this car still has to drive along the group's road to `point`; `nil` without a position or once the
    /// point is behind.
    func DistanceAlongRoad(to point: Coordinate) -> Double? {
        let road = state.groupPath
        guard let myCoordinate, let mine = RoutePosition.Locate(myCoordinate, on: road),
              let target = RoutePosition.Locate(point, on: road) else { return nil }
        let metres = target.distanceAlongRoute - mine.distanceAlongRoute
        return metres > 0 ? metres : nil
    }

    // MARK: Mute

    /// "Mute Lezgo" / "Unmute Lezgo", after the switch has changed.
    static func Mute(isMuted: Bool) -> String {
        String(localized: isMuted ? .siriMuted : .siriUnmuted)
    }

    // MARK: I've arrived

    /// Whether Siri may ask "Arrived at …?", with the same rules as the "I've Arrived" button (US-07).
    enum Arrival: Hashable {
        /// Ask first, then save this confirmation.
        case ask(TripMapManualArrival.Confirmation)
        /// Nothing to ask: say this instead.
        case refuse(String)
    }

    /// "I've arrived in Lezgo".
    func ArrivalCheck() -> Arrival {
        guard state.trip.status == .inTrip, let destination = state.destination else { return .refuse(Self.noTrip) }
        guard let myCoordinate else { return .refuse(String(localized: .siriMyLocationUnknown)) }
        if TripMapArrival.Check(state, myParticipantID: myParticipantID, at: now).hasArrived {
            return .refuse(String(localized: .siriAlreadyArrived))
        }
        let metres = myCoordinate.Distance(to: destination.coordinate)
        guard metres <= TripMapManualArrival.maxDistance else {
            return .refuse(String(localized: .siriArrivedTooFar(Spoken(metres: metres), destination.name)))
        }
        let rounded = (metres / Self.roundedTo).rounded() * Self.roundedTo
        return .ask(TripMapManualArrival.Confirmation(
            destinationID: destination.id,
            destinationName: destination.name,
            distance: Measurement(value: rounded, unit: .meters)
        ))
    }

    /// "Arrived at Pakuwon mall?"
    static func ArrivalQuestion(_ confirmation: TripMapManualArrival.Confirmation) -> String {
        String(localized: .siriArrivedQuestion(confirmation.destinationName))
    }

    /// After saving "I've Arrived".
    static func Arrived(everyoneHasArrived: Bool) -> String {
        String(localized: everyoneHasArrived ? .tripMapEveryoneHasArrived : .siriArrivedWaiting)
    }

    // MARK: Distances

    /// "400 m" under 1 km (rounded to 10 m), "1.2 km" or "12 km" from 1 km.
    func Spoken(metres: Double) -> String {
        let style = Measurement<UnitLength>.FormatStyle(
            width: .abbreviated,
            usage: .asProvided,
            numberFormatStyle: .number.precision(.fractionLength(0...1))
        ).locale(locale)
        let rounded = (metres / Self.roundedTo).rounded() * Self.roundedTo
        guard rounded >= 1_000 else {
            return Measurement(value: rounded, unit: UnitLength.meters).formatted(style)
        }
        return Measurement(value: metres / 1_000, unit: UnitLength.kilometers).formatted(style)
    }
}
