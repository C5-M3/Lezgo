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
}
