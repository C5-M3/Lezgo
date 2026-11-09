//
//  ActiveTripMap.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 07/11/26.
//

import Foundation
import Observation

/// The trip map open on the phone, so CarPlay can mirror it (ADR 0023).
///
/// `TripMapView` shows its view model here while it is on screen. The CarPlay scene reads it, so the phone and the
/// car show one trip with one GPS feed and one set of alerts.
@Observable
final class ActiveTripMap {
    /// The one the app uses. UIKit creates the CarPlay scene delegate itself, so it cannot be handed one; tests and
    /// previews make their own.
    static let shared = ActiveTripMap()

    /// The trip map on the phone's screen, or `nil` while none is open.
    private(set) var tripMap: TripMapViewModel?

    func Show(_ tripMap: TripMapViewModel) {
        self.tripMap = tripMap
    }

    /// Only the map that is shown clears it: a new map can open before the old one has gone.
    func Hide(_ tripMap: TripMapViewModel) {
        guard self.tripMap === tripMap else { return }
        self.tripMap = nil
    }
}
