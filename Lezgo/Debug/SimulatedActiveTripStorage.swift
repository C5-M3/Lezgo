//
//  SimulatedActiveTripStorage.swift
//  Lezgo
//
//  Created by Oky Faishal on 29/10/26.
//

#if DEBUG
import Foundation

/// Keeps the saved trip in memory for simulated screens and previews, so trying Exit there never clears the trip
/// saved on the phone (`UserDefaultsActiveTripStorage` shares the app's `UserDefaults`).
final class SimulatedActiveTripStorage: ActiveTripStorage, @unchecked Sendable {
    private var summary: ActiveTripSummary?

    init(summary: ActiveTripSummary? = nil) {
        self.summary = summary
    }

    func SaveActiveTrip(_ summary: ActiveTripSummary) {
        self.summary = summary
    }

    func LoadActiveTrip() -> ActiveTripSummary? {
        summary
    }

    func ClearActiveTrip() {
        summary = nil
    }
}
#endif
