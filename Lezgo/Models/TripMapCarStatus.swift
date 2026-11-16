//
//  TripMapCarStatus.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 28/10/26.
//

import Foundation

/// What the car status card shows for a tapped car (`specs/UserStories.md` → US-06, "Car status"): the driver,
/// what the car is doing and where, and its time left to the destination.
struct TripMapCarStatus: Identifiable, Hashable {
    /// "3 min" or "1 hr, 5 min", like the time left on the bottom card.
    static let durationStyle = Duration.UnitsFormatStyle(allowedUnits: [.hours, .minutes], width: .abbreviated)

    let id: UUID
    var displayName: String
    var activity: Activity
    /// `nil` until the travel time is known, and for an offline car, whose last position is out of date.
    var timeLeft: Duration?
    /// The name of the checkpoint the car heads for, or the destination once every checkpoint is visited; the card
    /// shows it beside the time left.
    var nextStopName: String?
    /// "Black Brio"; empty when the driver has not typed one.
    var carDescription = ""
    var carColor = TripMapCarPin.CarColor.yellow

    /// "Driving at Ahmad Yani Street", "Stopped at Ahmad Yani Street" or "Last seen 3 min ago".
    var statusLine: String {
        switch activity {
        case .driving(let street?): String(localized: .tripMapCarDrivingAt(street))
        case .driving(nil): String(localized: .tripMapCarDriving)
        case .stopped(let street?): String(localized: .tripMapCarStoppedAt(street))
        case .stopped(nil): String(localized: .tripMapCarStopped)
        case .offline(let lastSeen):
            String(localized: .tripMapCarLastSeen(lastSeen.formatted(Self.durationStyle)))
        }
    }

    /// "Status: Driving", the line the card shows under the car, as in the hi-fi.
    var cardStatusLine: String {
        let title = switch activity {
        case .driving: String(localized: .tripMapCarDriving)
        case .stopped: String(localized: .tripMapCarStopped)
        case .offline: String(localized: .tripMapCarOffline)
        }
        return String(localized: .tripMapCarStatusLabel(title))
    }

    /// "To Tunjungan Plaza"; `nil` for an offline car, whose last position is out of date, and without a name.
    var nextStopLine: String? {
        guard timeLeft != nil, let nextStopName else { return nil }
        return String(localized: .tripMapCarTo(nextStopName))
    }

    /// "Last seen 3 min ago" for an offline car, which the status line alone does not say.
    var lastSeenLine: String? {
        guard case .offline = activity else { return nil }
        return statusLine
    }

    /// What the car is doing.
    enum Activity: Hashable {
        /// Moving. `street` is `nil` until the street is known.
        case driving(street: String?)
        /// Speed 0 for 30 seconds. `street` is `nil` until the street is known.
        case stopped(street: String?)
        /// No location for more than 2 minutes; `lastSeen` is how long ago the last one came.
        case offline(lastSeen: Duration)
    }
}
