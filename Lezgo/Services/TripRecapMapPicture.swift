//
//  TripRecapMapPicture.swift
//  Lezgo
//

import MapKit
import UIKit

/// A square still map of a finished trip for the share picture: MapKit draws the streets, and the card draws the
/// route and the two pins on top at `routePoints`, `startPoint` and `destinationPoint`.
struct TripRecapMapPicture {
    let image: UIImage
    let routePoints: [CGPoint]
    let startPoint: CGPoint
    let destinationPoint: CGPoint

    /// `nil` when MapKit cannot draw the area.
    static func Make(recap: TripRecap) async -> TripRecapMapPicture? {
        nil
    }
}
