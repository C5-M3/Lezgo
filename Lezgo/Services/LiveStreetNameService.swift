//
//  LiveStreetNameService.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 28/10/26.
//

import MapKit

/// Names the street at a coordinate with MapKit reverse geocoding.
///
/// MapKit gives the nearest address or place, for example "Jalan Tegal Sari No. 28" or "Ciputra World Surabaya".
/// It needs the network; the caller decides how often to ask, because Apple limits how many requests an app sends.
struct LiveStreetNameService: StreetNameService {
    func StreetName(at coordinate: Coordinate) async throws -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        return try await request.mapItems.first?.name
    }
}
