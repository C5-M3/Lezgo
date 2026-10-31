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
