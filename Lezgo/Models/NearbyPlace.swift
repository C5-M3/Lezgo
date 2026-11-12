//
//  NearbyPlace.swift
//  Lezgo
//

import Foundation

/// A place close to the pin on the map picker, shown as a chip the person can snap the pin to.
struct NearbyPlace: Identifiable, Equatable {
    let name: String
    let subtitle: String
    let coordinate: Coordinate

    var id: String { "\(name)@\(coordinate.latitude),\(coordinate.longitude)" }
}
