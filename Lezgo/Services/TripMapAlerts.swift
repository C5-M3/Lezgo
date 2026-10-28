//
//  TripMapAlerts.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 28/10/26.
//

import Foundation

/// The formation alerts as one phone sees them: its own alert, worked out from every new trip state, which banner
/// to show, and the banners closed with ⓧ (`specs/UserStories.md` → US-06, "Formation alerts").
struct TripMapAlerts {
    let myParticipantID: UUID
    /// This phone's own alert, from its latest position.
    private(set) var myAlert: FormationAlert = .none
    private var detector = FormationAlertDetector()
    /// The alert last saved for this phone, or `nil` before the first save.
    private var savedAlert: FormationAlert?
    /// Banners closed with ⓧ, by car. Each stays hidden until that car's alert ends or changes.
    private var closedAlerts: [UUID: FormationAlert] = [:]

    init(myParticipantID: UUID) {
        self.myParticipantID = myParticipantID
    }

    /// Works out my alert from the new state. Returns the alert to save when it differs from the saved one; the
    /// leader never saves one.
    mutating func Update(_ state: TripState) -> FormationAlert? {
        myAlert = detector.Update(state, for: myParticipantID)
        ForgetEndedClosedAlerts(in: state)
        let me = state.participants.first { $0.id == myParticipantID }
        guard let me, me.IsLeader(in: state.trip) == false, myAlert != (savedAlert ?? me.alert) else { return nil }
        return myAlert
    }

    /// The service saved `alert`, so it is not sent again while it lasts.
    mutating func Saved(_ alert: FormationAlert) {
        savedAlert = alert
    }

    /// The one banner to show: my own alert first, then another car off the route, then one ahead of the leader.
    /// A passed checkpoint is shown only to that car.
    func Banner(in state: TripState, at date: Date) -> Banner? {
        if myAlert != .none, closedAlerts[myParticipantID] != myAlert {
            return .mine(myAlert)
        }
        let car = state.participants
            .filter { IsShared($0, at: date) && closedAlerts[$0.id] != $0.alert }
            .min { (Order($0.alert), $0.displayName) < (Order($1.alert), $1.displayName) }
        guard let car else { return nil }
        return .otherCar(id: car.id, name: car.displayName, alert: car.alert)
    }

    /// ⓧ on the banner: hides it until that alert happens again.
    mutating func Close(_ banner: Banner) {
        switch banner {
        case .mine(let alert): closedAlerts[myParticipantID] = alert
        case let .otherCar(id, _, alert): closedAlerts[id] = alert
        }
    }

    /// Whether another car's alert shows on this phone: off the route or ahead of the leader, while it is online.
    func IsShared(_ participant: Participant, at date: Date) -> Bool {
        participant.id != myParticipantID
            && (participant.alert == .offRoute || participant.alert == .aheadOfLeader)
            && participant.IsOnline(at: date)
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
        /// This phone's own alert: "You're out of the way", "You pass a checkpoint" or "You Precede The Leader".
        case mine(FormationAlert)
        /// Another car's alert: "Car Budi - Out of The Way" or "Car Budi - Precede The Leader".
        case otherCar(id: UUID, name: String, alert: FormationAlert)
    }
}
