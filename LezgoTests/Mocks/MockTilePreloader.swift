//
//  MockTilePreloader.swift
//  LezgoTests
//

import CoreLocation
@testable import Lezgo

/// Loads nothing: it answers once `isReady` is true, as the tiles would once they have arrived, and remembers what
/// it was asked for.
final class MockTilePreloader: TilePreloading {
    /// Whether the close-up levels have loaded.
    var isReady: Bool
    /// Whether the wide overview of a place has loaded.
    var overviewIsReady = true
    /// An area this wide or wider is an overview of a place, not a close-up level.
    static let overviewThreshold: CLLocationDistance = 500_000
    private(set) var requestedCoordinates: [CLLocationCoordinate2D] = []
    private(set) var requestedAreas: [CLLocationDistance] = []

    init(isReady: Bool = true) {
        self.isReady = isReady
    }

    func Preload(around coordinate: CLLocationCoordinate2D, areaMeters: CLLocationDistance) async -> Bool {
        requestedCoordinates.append(coordinate)
        requestedAreas.append(areaMeters)
        let isOverview = areaMeters >= Self.overviewThreshold
        while !(isOverview ? overviewIsReady : isReady) && !Task.isCancelled { await Task.yield() }
        return !Task.isCancelled
    }
}
