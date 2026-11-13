//
//  PlaceAddress.swift
//  Lezgo
//

import Foundation

/// The address of a pinned place: the street (or place) and the area under it, which go into the route, and the
/// place's own name when MapKit knows one, which the map picker shows.
struct PlaceAddress: Equatable {
    let street: String
    let area: String
    /// The place's own name, such as "Royal Plaza"; `nil` when MapKit has none.
    var placeName: String?
}
