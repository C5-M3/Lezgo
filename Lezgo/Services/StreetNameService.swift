//
//  StreetNameService.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 28/10/26.
//

import Foundation

/// Names the street a car is on, for the car status card ("Driving at Ahmad Yani Street").
///
/// `LiveStreetNameService` asks MapKit; tests use `MockStreetNameService`.
protocol StreetNameService {
    /// The street or place at `coordinate`, or `nil` when the map knows no name there.
    func StreetName(at coordinate: Coordinate) async throws -> String?
}
