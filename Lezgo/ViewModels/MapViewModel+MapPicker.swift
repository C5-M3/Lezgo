//
//  MapViewModel+MapPicker.swift
//  Lezgo
//

import CoreLocation
import Foundation

// MARK: - Choose on Map

extension MapViewModel {
    /// Where the map opens when nothing else says: the middle of Surabaya, where the team tests.
    private static let fallbackPickerStart = Coordinate(latitude: -7.2575, longitude: 112.7521)

    /// Opens the map for the point the search was for.
    func StartPickingOnMap() {
        guard let selection = activeSelectionSheet else { return }
        let picker = MapPickerViewModel(
            selection: selection,
            startingAt: PickerStart(for: selection),
            lookupService: placeLookupService
        )
        picker.Start()
        mapPicker = picker
    }

    /// Puts the pinned place where the search was for, exactly like a picked search result.
    func ConfirmMapPick() {
        guard let picker = mapPicker else { return }
        let point = picker.MakePoint()
        mapPicker = nil
        ApplySearchResult(point)
    }

    /// Closes the map and leaves the route as it was.
    func CancelMapPick() {
        mapPicker = nil
    }

    private func PickerStart(for selection: ActivePointSelection) -> Coordinate {
        let editedPoint: RoutePoint? = switch selection {
        case .start: startPoint
        case .destination(let index): destinations.indices.contains(index) ? destinations[index] : nil
        }
        let coordinate = editedPoint?.coordinate
            ?? destinations.last?.coordinate
            ?? startPoint?.coordinate
            ?? locationService.userLocation
        guard let coordinate else { return Self.fallbackPickerStart }
        return Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}
