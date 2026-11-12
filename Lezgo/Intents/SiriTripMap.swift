//
//  SiriTripMap.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Foundation

/// Where every Siri intent finds the trip (ADR 0030): the trip map open on this phone, the same one CarPlay mirrors.
struct SiriTripMap {
    let tripMap: TripMapViewModel
    let answers: TripAnswers

    /// The open trip map with its answers, or `nil` with no trip on the road (no trip, the Trip Room, or a closed map).
    static func Current(in activeTripMap: ActiveTripMap = .shared) -> SiriTripMap? {
        guard let tripMap = activeTripMap.tripMap, let answers = tripMap.SiriAnswers() else { return nil }
        return SiriTripMap(tripMap: tripMap, answers: answers)
    }

    /// A trip on the road, in the Trip Room or a draft (US-03): "Join a trip" and "Create a trip" leave it alone.
    @MainActor
    static func HasTripOnThisPhone(
        activeTripMap: ActiveTripMap = .shared,
        storage: any ActiveTripStorage = UserDefaultsActiveTripStorage()
    ) -> Bool {
        activeTripMap.tripMap != nil || storage.LoadActiveTrip() != nil
    }
}
