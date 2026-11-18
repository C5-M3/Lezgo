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

    /// The side of the square map on the card, in points.
    static let side = 140.0
    /// The same scale as the finished picture (1080 pixels over 360 points), so the streets stay sharp.
    static let scale = 3.0

    /// `nil` when MapKit cannot draw the area.
    static func Make(recap: TripRecap) async -> TripRecapMapPicture? {
        let configuration = MKStandardMapConfiguration(emphasisStyle: .muted)
        configuration.pointOfInterestFilter = .excludingAll
        let options = MKMapSnapshotter.Options()
        options.mapRect = Square(around: recap.boundingRect)
        options.size = CGSize(width: side, height: side)
        options.scale = scale
        options.preferredConfiguration = configuration
        // The recap screen is always dark, so the picture's map is too.
        options.traitCollection = UITraitCollection(userInterfaceStyle: .dark)

        guard let snapshot = try? await MKMapSnapshotter(options: options).start() else { return nil }
        return TripRecapMapPicture(
            image: snapshot.image,
            routePoints: recap.polyline.map { snapshot.point(for: $0.locationCoordinate) },
            startPoint: snapshot.point(for: recap.startCoordinate.locationCoordinate),
            destinationPoint: snapshot.point(for: recap.destinationCoordinate.locationCoordinate)
        )
    }

    /// The smallest square that holds `rect`, with the same centre, so MapKit does not have to change its shape.
    private static func Square(around rect: MKMapRect) -> MKMapRect {
        let length = max(rect.size.width, rect.size.height)
        return MKMapRect(x: rect.midX - length / 2, y: rect.midY - length / 2, width: length, height: length)
    }
}
