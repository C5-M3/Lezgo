//
//  ActiveTripStorage.swift
//  Lezgo
//
//  Created by Rizal Pratama on 27/10/26.
//

import Foundation

/// Local persistence protocol for the active or draft trip summary (US-03).
protocol ActiveTripStorage: Sendable {
    func SaveActiveTrip(_ summary: ActiveTripSummary)
    func LoadActiveTrip() -> ActiveTripSummary?
    func ClearActiveTrip()
}

/// Stores the active trip summary in UserDefaults as JSON data.
final class UserDefaultsActiveTripStorage: ActiveTripStorage, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let storageKey: String

    init(userDefaults: UserDefaults = .standard, storageKey: String = "active_trip_summary") {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
    }

    func SaveActiveTrip(_ summary: ActiveTripSummary) {
        guard let data = try? JSONEncoder().encode(summary) else { return }
        userDefaults.set(data, forKey: storageKey)
    }

    func LoadActiveTrip() -> ActiveTripSummary? {
        guard let data = userDefaults.data(forKey: storageKey),
              let summary = try? JSONDecoder().decode(ActiveTripSummary.self, from: data) else {
            return nil
        }
        return summary
    }

    func ClearActiveTrip() {
        userDefaults.removeObject(forKey: storageKey)
    }
}
