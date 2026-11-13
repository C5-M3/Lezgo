//
//  MKMapItem+Lezgo.swift
//  Lezgo
//

import MapKit

/// Making a map item from a coordinate and reading its coordinate back. MapKit's `init(location:address:)` and
/// `location` start in iOS 26; before that a map item holds an `MKPlacemark` (ADR 0031). Callers use these two and
/// never check the iOS version themselves.
extension MKMapItem {
    /// A map item at `coordinate` with no address, for directions requests and CarPlay guidance.
    nonisolated static func Make(at coordinate: CLLocationCoordinate2D) -> MKMapItem {
        if #available(iOS 26.0, *) {
            return MKMapItem(
                location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
                address: nil
            )
        }
        return MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
    }

    /// Where the item is on the map.
    nonisolated var placeCoordinate: CLLocationCoordinate2D {
        if #available(iOS 26.0, *) {
            return location.coordinate
        }
        return placemark.coordinate
    }

    /// The item's "Place, City" address: MapKit's `MKAddress` on iOS 26, its placemark before that.
    nonisolated var shortAddressText: String? {
        if #available(iOS 26.0, *) {
            return address?.shortAddress
        }
        return placemark.shortAddress
    }
}
