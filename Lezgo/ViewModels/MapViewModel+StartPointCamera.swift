//
//  MapViewModel+StartPointCamera.swift
//  Lezgo
//

import MapKit
import SwiftUI

extension MapViewModel {
    /// A street-level view around the new start point, about 1.5 km across: where every move ends.
    static let closeUpArea: CLLocationDistance = 1_500
    /// Nearer than this, the camera just flies there: the tiles on the way are few.
    static let shortHop: CLLocationDistance = 5_000
    /// How much of the map the camera sees while it crosses, compared with the distance: both places fit, with room
    /// around them.
    static let overviewMargin = 1.6
    /// The overview is never tighter than a neighbourhood or wider than most of the world.
    static let overviewLimits: ClosedRange<CLLocationDistance> = 8_000...15_000_000
    /// The camera zooms in from the overview to the close-up in at most this many steps, each at most this many times
    /// closer than the last, so a short move has few steps and a long one has more.
    static let maximumZoomInSteps = 4
    static let maximumStepRatio = 8.0

    /// How much of the map, in meters across, the camera sees while it crosses `distance`.
    static func OverviewArea(forDistance distance: CLLocationDistance) -> CLLocationDistance {
        min(max(distance * overviewMargin, overviewLimits.lowerBound), overviewLimits.upperBound)
    }

    /// The areas, in meters across, the camera zooms in through from `overview`, widest first. Each is the same
    /// number of times closer than the last, and the last is the close-up.
    static func ZoomInAreas(from overview: CLLocationDistance) -> [CLLocationDistance] {
        let total = overview / closeUpArea
        guard total > 1 else { return [closeUpArea] }
        let steps = min(maximumZoomInSteps, max(1, Int((log(total) / log(maximumStepRatio)).rounded(.up))))
        let ratio = pow(total, 1 / Double(steps))
        return (1...steps).map { $0 == steps ? closeUpArea : overview / pow(ratio, Double($0)) }
    }
    static let zoomOutFlight = Animation.easeInOut(duration: 0.8)
    static let crossingFlight = Animation.easeInOut(duration: 1.0)
    static let zoomInFlight = Animation.easeInOut(duration: 0.8)

    /// Shows the map around a new start point without the empty map of a place still loading. A far start point is
    /// reached in steps: the camera zooms out just far enough to see both places, crosses the distance where a few
    /// coarse tiles cover the screen, and zooms in one level at a time. Each step waits for its tiles, which are all
    /// requested at the start so they load while the camera is still on its way.
    func ShowStart(from previous: CLLocationCoordinate2D?, to coordinate: CLLocationCoordinate2D) {
        startMoveTask?.cancel()
        guard let previous, Self.Distance(from: previous, to: coordinate) > Self.shortHop else {
            FlyCamera(to: Self.CloseUp(of: coordinate))
            return
        }
        startMoveTask = Task { await FlyInSteps(from: previous, to: coordinate) }
    }

    private func FlyInSteps(from previous: CLLocationCoordinate2D, to coordinate: CLLocationCoordinate2D) async {
        // The overview of both places, then every close-up level, are requested at once and load while the camera is
        // still on its way. The camera moves only to what is loaded, so the empty map never shows.
        let overview = Self.OverviewArea(forDistance: Self.Distance(from: previous, to: coordinate))
        let zoomInAreas = Self.ZoomInAreas(from: overview)
        let overviewOfOld = TileLoad(preloader: tilePreloader, coordinate: previous, area: overview)
        let overviewOfNew = TileLoad(preloader: tilePreloader, coordinate: coordinate, area: overview)
        let loads = zoomInAreas.map { TileLoad(preloader: tilePreloader, coordinate: coordinate, area: $0) }
        let allLoads = [overviewOfOld, overviewOfNew] + loads
        defer { allLoads.forEach { $0.Cancel() } }

        await WaitForTiles(of: overviewOfOld)
        guard !Task.isCancelled else { return }
        withAnimation(Self.zoomOutFlight) {
            cameraPosition = Self.View(of: previous, area: overview)
        }
        try? await Task.sleep(for: zoomOutTime)
        guard !Task.isCancelled else { return }

        await WaitForTiles(of: overviewOfNew)
        guard !Task.isCancelled else { return }
        withAnimation(Self.crossingFlight) {
            cameraPosition = Self.View(of: coordinate, area: overview)
        }
        try? await Task.sleep(for: crossingTime)

        for (area, load) in zip(zoomInAreas, loads) {
            await WaitForTiles(of: load)
            guard !Task.isCancelled else { return }
            withAnimation(Self.zoomInFlight) {
                cameraPosition = Self.View(of: coordinate, area: area)
            }
            try? await Task.sleep(for: zoomInTime)
            guard !Task.isCancelled else { return }
        }
    }

    /// Waits for the tiles, but never longer than `tileWaitLimit`: a slow or missing network must not keep the camera
    /// from arriving. It looks at the load now and then instead of awaiting it, because awaiting a task cannot be
    /// cut short.
    private func WaitForTiles(of load: TileLoad) async {
        let deadline = ContinuousClock.now.advanced(by: tileWaitLimit)
        while !load.isFinished, ContinuousClock.now < deadline, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    static func Distance(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: start.latitude, longitude: start.longitude)
            .distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))
    }
}

/// One request for the tiles of an area, started at once and looked at later.
private final class TileLoad {
    private(set) var isFinished = false
    private var task: Task<Void, Never>?

    init(preloader: any TilePreloading, coordinate: CLLocationCoordinate2D, area: CLLocationDistance) {
        task = Task {
            _ = await preloader.Preload(around: coordinate, areaMeters: area)
            isFinished = true
        }
    }

    func Cancel() {
        task?.cancel()
    }
}
