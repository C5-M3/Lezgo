//
//  LivePlaceLookupService.swift
//  Lezgo
//

import MapKit

/// Looks up the pinned place with MapKit: reverse geocoding for the address and a points-of-interest search for the
/// nearby chips. Both need the network, and Apple limits how many requests an app sends, so the caller decides how
/// often to ask.
struct LivePlaceLookupService: PlaceLookupService {
    /// How far from the pin a place can be to count as nearby, in metres.
    static let nearbyRadius: CLLocationDistance = 500
    /// The most chips the picker shows.
    static let nearbyLimit = 5

    func Address(at coordinate: Coordinate) async throws -> PlaceAddress? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        let item = try await request.mapItems.first
        return Self.MakeAddress(shortAddress: item?.address?.shortAddress, name: item?.name)
    }

    func NearbyPlaces(around coordinate: Coordinate) async throws -> [NearbyPlace] {
        let request = MKLocalPointsOfInterestRequest(center: coordinate.locationCoordinate, radius: Self.nearbyRadius)
        let response = try await MKLocalSearch(request: request).start()
        let candidates = response.mapItems.compactMap { item -> NearbyPlace? in
            guard let name = item.name, name.isEmpty == false else { return nil }
            let subtitle = Self.MakeAddress(shortAddress: item.address?.shortAddress, name: nil)?.street ?? ""
            return NearbyPlace(
                name: name,
                subtitle: subtitle,
                coordinate: Coordinate(
                    latitude: item.location.coordinate.latitude,
                    longitude: item.location.coordinate.longitude
                )
            )
        }
        return Self.Closest(from: candidates, around: coordinate, limit: Self.nearbyLimit)
    }

    /// The street and area from what MapKit returned. The short address reads "Street, Area, City"; the street is the
    /// part before the first comma. Without a short address the place's name stands in for the street.
    static func MakeAddress(shortAddress: String?, name: String?) -> PlaceAddress? {
        let parts = shortAddress?.split(separator: ",", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        if let street = parts?.first, street.isEmpty == false {
            return PlaceAddress(street: street, area: parts?.dropFirst().first ?? "")
        }
        guard let name, name.isEmpty == false else { return nil }
        return PlaceAddress(street: name, area: "")
    }

    /// The places nearest to `center`, each name once, at most `limit` of them.
    static func Closest(from places: [NearbyPlace], around center: Coordinate, limit: Int) -> [NearbyPlace] {
        var seenNames: Set<String> = []
        return places
            .sorted { $0.coordinate.Distance(to: center) < $1.coordinate.Distance(to: center) }
            .filter { seenNames.insert($0.name).inserted }
            .prefix(limit)
            .map { $0 }
    }
}
