//
//  PlaceAddress.swift
//  Lezgo
//

import Foundation

/// The address of a pinned place, split the way the map picker card shows it: the street (or place) on the first
/// line and the area under it.
struct PlaceAddress: Equatable {
    let street: String
    let area: String
}
