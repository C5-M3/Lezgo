//
//  Coordinate.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import CoreLocation

/// A point on Earth, in degrees.
struct Coordinate: Hashable, Codable {
    var latitude: Double
    var longitude: Double

    var locationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Straight-line distance in metres, measured on the Earth's surface.
    func Distance(to other: Coordinate) -> CLLocationDistance {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }
}
