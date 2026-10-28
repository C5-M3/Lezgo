//
//  LiveStreetNameService.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 28/10/26.
//

import MapKit

/// Names the street at a coordinate with MapKit reverse geocoding.
///
/// MapKit gives the nearest address, for example "Jalan Tegal Sari No. 28", or a place when the address has no street
/// ("Tunjungan Plaza"). It needs the network; the caller decides how often to ask, because Apple limits how many
/// requests an app sends.
struct LiveStreetNameService: StreetNameService {
    func StreetName(at coordinate: Coordinate) async throws -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        let item = try await request.mapItems.first
        return Self.StreetName(shortAddress: item?.address?.shortAddress, name: item?.name)
    }

    /// The name to show on the card, from what MapKit returned.
    ///
    /// Next to a building, `name` is the building ("Ciputra World Surabaya") while the short address still starts
    /// with the street ("Jl Kencanasari Barat VII No. L-17 A, Surabaya"). The city after the first comma is left out,
    /// because it is the same for every car in the trip.
    static func StreetName(shortAddress: String?, name: String?) -> String? {
        let street = shortAddress?
            .split(separator: ",", maxSplits: 1)
            .first?
            .trimmingCharacters(in: .whitespaces)
        guard let street, street.isEmpty == false else { return name }
        return street
    }
}
