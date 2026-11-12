//
//  PlaceLookupService.swift
//  Lezgo
//

import Foundation

/// Tells the map picker what is at the pin and what is around it.
///
/// `LivePlaceLookupService` asks MapKit; tests use `MockPlaceLookupService`.
protocol PlaceLookupService {
    /// The address at `coordinate`, or `nil` when the map knows nothing there.
    func Address(at coordinate: Coordinate) async throws -> PlaceAddress?

    /// Places around `coordinate`, nearest first.
    func NearbyPlaces(around coordinate: Coordinate) async throws -> [NearbyPlace]
}
