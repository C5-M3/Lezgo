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
    /// "Agus is offline"
    case leaderOffline(name: String)
    /// "Budi is now the leader"
    case newLeader(name: String)

    /// How long a notice about something that has just happened stays, in seconds; `nil` for one that lasts as long
    /// as the situation does.
    var secondsOnScreen: Int? {
        switch self {
        case .newRoute, .routeUpdated, .newLeader: 5
        case .rerouteFailed, .leaderOffline: nil
        }
    }
}
