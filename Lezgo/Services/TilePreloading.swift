//
//  TilePreloading.swift
//  Lezgo
//

import CoreLocation
import MapKit
import UIKit

/// Loads the map tiles of an area ahead of the camera, so tests can pass in a fake instead of MapKit.
protocol TilePreloading {
    /// Returns once the tiles of the area, `areaMeters` across, are loaded: `true`, or `false` when MapKit could not
    /// load them (no network, for example).
    func Preload(around coordinate: CLLocationCoordinate2D, areaMeters: CLLocationDistance) async -> Bool
}

/// Takes a map snapshot of the area and drops the picture. A snapshot only finishes once its tiles are loaded, which
/// is what the camera waits for. The snapshot has the look of the map on screen (standard style, dark, the size of
/// the screen and the device's scale), so it loads the tiles the map will show and not others. MapKit delivers a
/// snapshot only while the app is in the foreground, which is why the camera does not wait for it forever.
struct LiveTilePreloader: TilePreloading {
    func Preload(around coordinate: CLLocationCoordinate2D, areaMeters: CLLocationDistance) async -> Bool {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: areaMeters,
            longitudinalMeters: areaMeters
        )
        options.size = CGSize(width: 390, height: 844)
        options.traitCollection = UITraitCollection(userInterfaceStyle: .dark)
        return (try? await MKMapSnapshotter(options: options).start()) != nil
    }
}
