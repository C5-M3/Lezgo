//
//  SiriMapPicture.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import MapKit
import UIKit

/// A still map for a Siri card (US-08): Siri cards cannot hold a live map, so MapKit draws a picture of the area
/// around the cars, and the card draws the route line and the robots on top at `points`.
struct SiriMapPicture {
    let image: UIImage
    /// Where each car is on the picture, in the order they were given.
    let carPoints: [CGPoint]
    /// The group's road on the picture.
    let routePoints: [CGPoint]

    /// The card's map size, in points.
    static let size = CGSize(width: 350, height: 150)
    /// Room around the cars, so the robots are not cut at the edge.
    private static let padding = 1.6
    /// The smallest area shown, in metres, so two cars side by side still show their street.
    private static let minimumSpan = 400.0

    /// `nil` when MapKit cannot draw the area, for example with no network; the card then shows no map.
    static func Make(cars: [Coordinate], route: [Coordinate]) async -> SiriMapPicture? {
        guard let options = Options(cars: cars) else { return nil }
        guard let snapshot = try? await MKMapSnapshotter(options: options).start() else { return nil }
        return SiriMapPicture(
            image: snapshot.image,
            carPoints: cars.map { snapshot.point(for: $0.locationCoordinate) },
            routePoints: route.map { snapshot.point(for: $0.locationCoordinate) }
        )
    }

    private static func Options(cars: [Coordinate]) -> MKMapSnapshotter.Options? {
        guard let first = cars.first else { return nil }
        let latitudes = cars.map(\.latitude)
        let longitudes = cars.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: ((latitudes.min() ?? first.latitude) + (latitudes.max() ?? first.latitude)) / 2,
            longitude: ((longitudes.min() ?? first.longitude) + (longitudes.max() ?? first.longitude)) / 2
        )
        let minimumDegrees = minimumSpan / 111_000
        let span = MKCoordinateSpan(
            latitudeDelta: max(((latitudes.max() ?? 0) - (latitudes.min() ?? 0)) * padding, minimumDegrees),
            longitudeDelta: max(((longitudes.max() ?? 0) - (longitudes.min() ?? 0)) * padding, minimumDegrees)
        )
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: center, span: span)
        options.size = size
        options.preferredConfiguration = MKStandardMapConfiguration(emphasisStyle: .muted)
        options.pointOfInterestFilter = .excludingAll
        return options
    }
}
