//
//  TripMapAlerts.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 28/10/26.
//

import Foundation

/// The formation alerts as one phone sees them: its own alert, worked out from every new trip state, which banner
/// to show, and the banners closed with a tap (`specs/UserStories.md` → US-06, "Formation alerts").
struct TripMapAlerts {
    let myParticipantID: UUID
    /// This phone's own alert, from its latest position.
    private(set) var myAlert: FormationAlert = .none
    private var detector = FormationAlertDetector()
    /// The alert last saved for this phone, or `nil` before the first save.
    private var savedAlert: FormationAlert?
    /// Banners closed with a tap, by car. Each stays hidden until that car's alert ends or changes.
    private var closedAlerts: [UUID: FormationAlert] = [:]
    /// Cars seen driving during this trip. A car still waiting at the start has not "stopped".
    private var carsSeenDriving: Set<UUID> = []
    /// "Has stopped" banners closed by a tap, by car. Each stays hidden until that car drives again.
    private var closedStops: Set<UUID> = []

    init(myParticipantID: UUID) {
        self.myParticipantID = myParticipantID
    }

    /// Works out my alert from the new state. Returns the alert to save when it differs from the saved one; the
    /// leader never saves one.
    mutating func Update(_ state: TripState) -> FormationAlert? {
        myAlert = detector.Update(state, for: myParticipantID)
        ForgetEndedClosedAlerts(in: state)
        let driving = state.participants.filter { $0.motionState == .driving }.map(\.id)
        carsSeenDriving.formUnion(driving)
        closedStops.subtract(driving)
        let me = state.participants.first { $0.id == myParticipantID }
        guard let me, me.IsLeader(in: state.trip) == false, myAlert != (savedAlert ?? me.alert) else { return nil }
        return myAlert
    }

    /// The service saved `alert`, so it is not sent again while it lasts.
    mutating func Saved(_ alert: FormationAlert) {
        savedAlert = alert
    }

    /// The one banner to show: my own alert first, then another car off the route, then one ahead of the leader, then
    /// a car that has stopped. A passed checkpoint is shown only to that car.
    func Banner(in state: TripState, at date: Date) -> Banner? {
        if myAlert != .none, closedAlerts[myParticipantID] != myAlert {
            return .mine(myAlert)
        }
        let car = state.participants
            .filter { IsShared($0, in: state, at: date) && closedAlerts[$0.id] != $0.alert }
            .min { (Order($0.alert), state.DisplayName(of: $0)) < (Order($1.alert), state.DisplayName(of: $1)) }
        if let car {
            return .otherCar(id: car.id, name: state.DisplayName(of: car), alert: car.alert)
        }
        let stopped = state.participants
            .filter { HasStopped($0, in: state, at: date) && closedStops.contains($0.id) == false }
            .min { state.DisplayName(of: $0) < state.DisplayName(of: $1) }
        return stopped.map { .carStopped(id: $0.id, name: state.DisplayName(of: $0)) }
    }

    /// A tap on the banner: hides it until that alert happens again.
    mutating func Close(_ banner: Banner) {
        switch banner {
        case .mine(let alert): closedAlerts[myParticipantID] = alert
        case let .otherCar(id, _, alert): closedAlerts[id] = alert
        case let .carStopped(id, _): closedStops.insert(id)
        }
    }

    /// Whether another car's alert shows on this phone: off the route or ahead of the leader, while it is online.
    /// The leader never has one; an alert saved before they got the lead is left over and is not shown.
    func IsShared(_ participant: Participant, in state: TripState, at date: Date) -> Bool {
        participant.id != myParticipantID
            && participant.IsLeader(in: state.trip) == false
            && (participant.alert == .offRoute || participant.alert == .aheadOfLeader)
            && participant.IsOnline(at: date)
    }

    /// Another online car that was driving and has stopped short of the destination. `motionState` turns to stopped
    /// after 30 seconds without moving, so a short stop in traffic does not count.
    private func HasStopped(_ participant: Participant, in state: TripState, at date: Date) -> Bool {
        guard participant.id != myParticipantID,
            participant.motionState == .stopped,
            carsSeenDriving.contains(participant.id),
            participant.IsOnline(at: date)
        else { return false }
        guard let destination = state.destination, let coordinate = participant.coordinate else { return true }
        return coordinate.Distance(to: destination.coordinate) > TripMapArrival.radius
    }

    /// A closed banner shows again once its alert has ended or changed and then happens again.
    private mutating func ForgetEndedClosedAlerts(in state: TripState) {
        let myAlert = myAlert
        let myParticipantID = myParticipantID
        closedAlerts = closedAlerts.filter { carID, closedAlert in
            let alert = carID == myParticipantID ? myAlert : state.participants.first { $0.id == carID }?.alert
            return alert == closedAlert
        }
    }

    /// Off the route is shown before ahead of the leader.
    private func Order(_ alert: FormationAlert) -> Int {
        alert == .offRoute ? 0 : 1
    }

    /// The formation alert banner under the turn card.
    enum Banner: Hashable {
        /// This phone's own alert: "You're out of the way", "You pass a checkpoint", "You passed the destination" or
        /// "You Precede The Leader".
        case mine(FormationAlert)
        /// Another car's alert: "Budi has gone out of route" or "Budi - Precede The Leader".
        case otherCar(id: UUID, name: String, alert: FormationAlert)
        /// Another car that was driving and has stopped: "Citra has stopped".
        case carStopped(id: UUID, name: String)
    }
}

extension TripMapAlerts.Banner {
    /// What the banner says, on the phone's pill and on CarPlay's navigation alert.
    var message: LocalizedStringResource {
        switch self {
        case .mine(.offRoute): .tripMapAlertOffRoute
        case .mine(.passedCheckpoint): .tripMapAlertPassedCheckpoint
        case .mine(.passedDestination): .tripMapAlertPassedDestination
        case .mine: .tripMapAlertAheadOfLeader
        case let .otherCar(_, name, .offRoute): .tripMapAlertCarOffRoute(name)
        case let .otherCar(_, name, _): .tripMapAlertCarAheadOfLeader(name)
        case let .carStopped(_, name): .tripMapAlertCarStopped(name)
        }
    }

    /// A car that has stopped is shown in red.
    var isUrgent: Bool {
        if case .carStopped = self { return true }
        return false
    }
}
