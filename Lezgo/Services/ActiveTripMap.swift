//
//  ActiveTripMap.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 07/11/26.
//

import Foundation
import Observation

/// The trip map open on the phone, so CarPlay can mirror it (ADR 0023).
@Observable
final class ActiveTripMap {
    private(set) var tripMap: TripMapViewModel?

    func Show(_ tripMap: TripMapViewModel) {}

    func Hide(_ tripMap: TripMapViewModel) {}
}
