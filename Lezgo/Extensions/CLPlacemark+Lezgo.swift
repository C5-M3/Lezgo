//
//  CLPlacemark+Lezgo.swift
//  Lezgo
//

import CoreLocation

/// The address text before iOS 26, when it comes from `CLGeocoder` instead of MapKit's `MKAddress` (ADR 0031).
extension CLPlacemark {
    /// The same "Place, City" text as `MKAddress.shortAddress`, so the street and area read the same on every version.
    nonisolated var shortAddress: String? {
        Self.ShortAddress(name: name, locality: locality)
    }

    /// For the same point MapKit's short address was the placemark's name, a comma and its city, for example
    /// "Jalan Jenderal Basuki Rachmat No. 8, Surabaya" or "Rumah Sakit Darmo, Surabaya". A missing part is left out.
    nonisolated static func ShortAddress(name: String?, locality: String?) -> String? {
        let parts = [name, locality]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { $0.isEmpty == false }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
