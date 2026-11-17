//
//  RoutingError.swift
//  Lezgo
//

import Foundation

/// Why a route could not be calculated, when the answer to the user is "wait" and not "no route".
enum RoutingError: Error, Equatable {
    /// MapKit allows only 50 directions requests per minute for the whole app and refused this one. `retryAfter` is
    /// the seconds until it answers again.
    case throttled(retryAfter: TimeInterval)
    /// MapKit has no drivable route between two stops, for example from Surabaya to Tokyo. It is not a distance
    /// limit (Surabaya to Medan works), so the planner says the stops are too far apart, not that something broke.
    case noRoute
}
