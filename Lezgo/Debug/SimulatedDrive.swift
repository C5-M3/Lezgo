//
//  SimulatedDrive.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 27/10/26.
//

#if DEBUG
import Foundation

/// Drives the sample trip's cars along its route, about once per second, through a `TripService`.
///
/// It plays the US-06 trip from `SampleTrip`: Agus leads, Budi drives 250 m behind him, and Citra stays offline at
/// the start point. Agus passes the checkpoint like a real leader would. Used with an `InMemoryTripService`, it
/// gives previews and `DebugScreen` a moving map without iCloud. Debug builds only.
struct SimulatedDrive {
    /// About 40 km/h.
    static let metresPerSecond = 11.0

    let tripService: any TripService
    /// How far into the drive to start, in seconds; a large value starts with the cars at the destination.
    var startSecond = 0
    var interval: Duration = .seconds(1)

    /// Moves the cars until the task is cancelled.
    func Run() async {
        var second = startSecond
        while Task.isCancelled == false {
            let agusDistance = 400 + Double(second) * Self.metresPerSecond
            await Move(SampleTrip.agusID, metresAlongRoute: agusDistance)
            await Move(SampleTrip.budiID, metresAlongRoute: agusDistance - 250)
            if agusDistance >= Self.DistanceAlongRoute(toPointAt: SampleTrip.checkpointRouteIndex) {
                try? await tripService.AdvanceCheckpoint(to: 2, tripID: SampleTrip.tripID, by: SampleTrip.agusID)
            }
            second += 1
            try? await Task.sleep(for: interval)
        }
    }

    private func Move(_ participantID: UUID, metresAlongRoute distance: Double) async {
        let hasArrived = distance >= Self.DistanceAlongRoute(toPointAt: SampleTrip.plan.polyline.count - 1)
        let update = LocationUpdate(
            coordinate: Self.Position(metresAlongRoute: distance),
            speedKmh: hasArrived ? 0 : Self.metresPerSecond * 3.6,
            motionState: hasArrived ? .stopped : .driving,
            recordedAt: .now
        )
        try? await tripService.UpdateLocation(update, participantID: participantID, tripID: SampleTrip.tripID)
    }

    /// Metres along the sample route from the start point to its point at `index`.
    static func DistanceAlongRoute(toPointAt index: Int) -> Double {
        let route = Array(SampleTrip.plan.polyline.prefix(index + 1))
        return zip(route, route.dropFirst()).reduce(0) { $0 + $1.0.Distance(to: $1.1) }
    }

    /// The point `distance` metres along the sample route, clamped to the start point and the destination.
    static func Position(metresAlongRoute distance: Double) -> Coordinate {
        let route = SampleTrip.plan.polyline
        var remaining = max(distance, 0)
        for (from, to) in zip(route, route.dropFirst()) {
            let length = from.Distance(to: to)
            if remaining <= length, length > 0 {
                let fraction = remaining / length
                return Coordinate(
                    latitude: from.latitude + (to.latitude - from.latitude) * fraction,
                    longitude: from.longitude + (to.longitude - from.longitude) * fraction
                )
            }
            remaining -= length
        }
        return route.last ?? Coordinate(latitude: 0, longitude: 0)
    }
}
#endif
