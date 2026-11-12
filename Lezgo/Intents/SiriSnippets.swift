//
//  SiriSnippets.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Foundation

/// Builds what Siri's cards show from the open trip map (US-08). The sentences come from `TripAnswers`; the cards add
/// robots, the map picture and times.
enum SiriSnippets {
    /// The answers right after a car was looked up, and its card; no card for this phone's own car.
    struct CarAnswer {
        let answers: TripAnswers
        let card: SiriCarSnippet?
    }

    /// The card for one car: its robot, what it is doing, its time left, and a map with both cars. Looks up the car's
    /// street and time left first, so the spoken answer can name the street.
    static func Car(_ carID: UUID, on tripMap: TripMapViewModel) async -> CarAnswer? {
        await tripMap.LookUpCar(carID)
        guard let answers = tripMap.SiriAnswers() else { return nil }
        let state = answers.state
        guard carID != answers.myParticipantID, let car = state.participants.first(where: { $0.id == carID }),
              let me = state.participants.first(where: { $0.id == answers.myParticipantID }) else {
            return CarAnswer(answers: answers, card: nil)
        }
        let isOnline = car.IsOnline(at: answers.now)
        let activity = String(localized: isOnline
            ? (car.motionState == .driving ? .tripMapCarDriving : .tripMapCarStopped)
            : .siriStatusOffline)
        let detail = car.IsLeader(in: state.trip) ? String(localized: .tripMapCarLeader) : car.carDescription
        let subtitle = detail.isEmpty ? activity : String(localized: .siriSubtitle(detail, activity))
        var map: SiriMapPicture?
        var gap: String?
        if isOnline, let mine = answers.myCoordinate, let theirs = car.coordinate {
            map = await SiriMapPicture.Make(cars: [mine, theirs], route: state.groupPath)
            let metres = answers.MeasureGap(from: mine, to: theirs).metres
            gap = metres > TripAnswers.nextToYou ? answers.Spoken(metres: metres) : nil
        }
        let card = SiriCarSnippet(
            car: .init(
                name: state.DisplayName(of: car),
                color: tripMap.CarColor(of: car, in: state),
                isLeader: car.IsLeader(in: state.trip),
                subtitle: subtitle,
                timeLeft: isOnline ? tripMap.carLookups[carID]?.timeLeft : nil
            ),
            myColor: tripMap.CarColor(of: me, in: state),
            gap: gap,
            map: map
        )
        return CarAnswer(answers: answers, card: card)
    }

    /// Cars that are not with the group first, so they always fit on the card; then the leader, this phone's car and
    /// the others in the order they joined.
    static func Group(_ answers: TripAnswers, on tripMap: TripMapViewModel) -> SiriGroupSnippet {
        let state = answers.state
        let ordered = state.participants.sorted { first, second in
            let firstIsWith = answers.ReasonNotWithGroup(first) == nil
            let secondIsWith = answers.ReasonNotWithGroup(second) == nil
            guard firstIsWith == secondIsWith else { return secondIsWith }
            return Rank(first, answers) < Rank(second, answers)
        }
        return SiriGroupSnippet(rows: ordered.map { car in
            let isMe = car.id == answers.myParticipantID
            return SiriGroupSnippet.Row(
                id: car.id,
                name: isMe ? String(localized: .tripMapCarYou) : state.DisplayName(of: car),
                color: tripMap.CarColor(of: car, in: state),
                isLeader: car.IsLeader(in: state.trip),
                subtitle: isMe ? state.DisplayName(of: car) : answers.ShortGap(to: car.id),
                reason: answers.ReasonNotWithGroup(car)
            )
        })
    }

    /// On the arrival card this phone's car comes first, then the leader.
    private static func ArrivalRank(_ car: Participant, _ answers: TripAnswers) -> Int {
        car.id == answers.myParticipantID ? -1 : Rank(car, answers)
    }

    private static func Rank(_ car: Participant, _ answers: TripAnswers) -> Int {
        if car.IsLeader(in: answers.state.trip) { return 0 }
        if car.id == answers.myParticipantID { return 1 }
        return 2 + (answers.state.participants.firstIndex { $0.id == car.id } ?? 0)
    }

    /// This car, the next checkpoint and the destination.
    static func TimeLeft(_ answers: TripAnswers) -> SiriTimeLeftSnippet? {
        guard let guidance = answers.guidance, let destination = answers.state.destination else { return nil }
        var stops = [SiriTimeLeftSnippet.Stop(kind: .me, name: String(localized: .tripMapCarYou))]
        if let checkpoint = answers.state.nextCheckpoint {
            let distance = answers.DistanceAlongRoad(to: checkpoint.coordinate)
            stops.append(.init(
                kind: .checkpoint,
                name: checkpoint.name,
                subtitle: distance.map { String(localized: .siriCheckpointDistance(answers.Spoken(metres: $0))) }
            ))
        }
        let distanceLeft = guidance.distanceLeft.map { answers.Spoken(metres: $0.converted(to: .meters).value) }
        stops.append(.init(
            kind: .destination,
            name: destination.name,
            subtitle: distanceLeft.map { String(localized: .siriDestinationDistance($0)) },
            timeLeft: guidance.timeLeft,
            arrival: answers.now.addingTimeInterval(TimeInterval(guidance.timeLeft.components.seconds))
        ))
        return SiriTimeLeftSnippet(stops: stops)
    }

    /// Every car's robot, this phone's car first and counted as arrived.
    static func Arrived(_ answers: TripAnswers, on tripMap: TripMapViewModel) -> SiriArrivedSnippet {
        let state = answers.state
        let ordered = state.participants.sorted { ArrivalRank($0, answers) < ArrivalRank($1, answers) }
        return SiriArrivedSnippet(cars: ordered.map { car in
            let isMe = car.id == answers.myParticipantID
            let hasArrived = isMe || state.destination.map { TripMapArrival.IsThere(car, at: $0) } == true
            return SiriArrivedSnippet.Car(
                id: car.id,
                name: isMe ? String(localized: .tripMapCarYou) : state.DisplayName(of: car),
                color: tripMap.CarColor(of: car, in: state),
                isLeader: car.IsLeader(in: state.trip),
                hasArrived: hasArrived
            )
        })
    }
}
