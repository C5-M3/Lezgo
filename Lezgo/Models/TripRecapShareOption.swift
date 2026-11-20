//
//  TripRecapShareOption.swift
//  Lezgo
//

import Foundation

/// One finished picture of the trip recap and the format it was drawn in.
struct TripRecapShareOption: Equatable, Identifiable {
    let format: TripRecapShareFormat
    let image: TripRecapShareImage

    var id: TripRecapShareFormat { format }
}
