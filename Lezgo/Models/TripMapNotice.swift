//
//  TripMapNotice.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 05/11/26.
//

import Foundation

/// A banner about the trip itself, under the turn card (`specs/UserStories.md` → US-06, "Route changes" and "Leader
/// offline"). The name is `nil` on the leader's own phone.
enum TripMapNotice: Hashable {
    /// "New route · Following Agus": the leader left the route and the group got a new one.
    case newRoute(leaderName: String?)
    /// "Route updated by Agus": the leader changed the stops.
    case routeUpdated(leaderName: String?)
    /// "Couldn't update the route. Trying again."
    case rerouteFailed
    /// "Agus is offline". Everyone stays on the current route; nobody takes over on the road.
    case leaderOffline(name: String)

    /// How long a notice about something that has just happened stays, in seconds; `nil` for one that lasts as long
    /// as the situation does.
    var secondsOnScreen: Int? {
        switch self {
        case .newRoute, .routeUpdated: 5
        case .rerouteFailed, .leaderOffline: nil
        }
    }

    /// A notice that something is wrong is shown in red.
    var isUrgent: Bool {
        switch self {
        case .rerouteFailed, .leaderOffline: true
        case .newRoute, .routeUpdated: false
        }
    }

    /// What the notice says, on the phone's pill and on CarPlay's navigation alert. A new route ends with the new
    /// time once guidance knows it: "New route · Following Agus · 52 min".
    func Message(timeLeft: Duration?) -> String {
        switch self {
        case let .newRoute(leaderName?): WithTime(.tripMapNoticeNewRouteFollowing(leaderName), timeLeft)
        case .newRoute(nil): WithTime(.tripMapNoticeNewRoute, timeLeft)
        case let .routeUpdated(leaderName?): WithTime(.tripMapNoticeRouteUpdatedBy(leaderName), timeLeft)
        case .routeUpdated(nil): WithTime(.tripMapNoticeRouteUpdated, timeLeft)
        case .rerouteFailed: String(localized: .tripMapNoticeRerouteFailed)
        case let .leaderOffline(name): String(localized: .tripMapNoticeLeaderOffline(name))
        }
    }

    private func WithTime(_ message: LocalizedStringResource, _ timeLeft: Duration?) -> String {
        guard let timeLeft else { return String(localized: message) }
        return "\(String(localized: message)) · \(timeLeft.formatted(TripMapCarStatus.durationStyle))"
    }
}
