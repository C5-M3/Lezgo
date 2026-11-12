//
//  SamplePlaceLookupService.swift
//  Lezgo
//

#if DEBUG
import Foundation

/// Answers the map picker with fixed Surabaya places, so its preview works without the network.
struct InMemoryPlaceLookupService: PlaceLookupService {
    func Address(at coordinate: Coordinate) async throws -> PlaceAddress? {
        PlaceAddress(street: "Jl. Raya Darmo No. 52", area: "Wonokromo, Surabaya")
    }

    func NearbyPlaces(around coordinate: Coordinate) async throws -> [NearbyPlace] {
        [
            NearbyPlace(
                name: "ITS",
                subtitle: "Keputih, Surabaya",
                coordinate: Coordinate(latitude: -7.2819, longitude: 112.7945)
            ),
            NearbyPlace(
                name: "Tunjungan Plaza",
                subtitle: "Genteng, Surabaya",
                coordinate: Coordinate(latitude: -7.2620, longitude: 112.7380)
            ),
            NearbyPlace(
                name: "Taman Bungkul",
                subtitle: "Darmo, Surabaya",
                coordinate: Coordinate(latitude: -7.2912, longitude: 112.7396)
            )
        ]
    }
}
#endif
