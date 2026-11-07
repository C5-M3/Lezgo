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
/// the start point. Agus passes the checkpoint like a real leader would. With `budiLeavesRoute`, Budi drives 150 m
/// beside the route and, after 15 seconds, saves the off route alert like Budi's phone would. Used with an
/// `InMemoryTripService`, it gives previews and `DebugScreen` a moving map without iCloud. Debug builds only.
struct SimulatedDrive {
    /// About 40 km/h.
    static let metresPerSecond = 11.0
    private static let budiStopSecond = 8
    private static let routeChangeSecond = 6

    let tripService: any TripService
    /// How far into the drive to start, in seconds; a large value starts with the cars at the destination.
    var startSecond = 0
    var interval: Duration = .seconds(1)
    /// Budi drives beside the route instead of on it, to show the formation alerts.
    var budiLeavesRoute = false
    /// Budi stops on the road after 8 seconds and stays there, to show the "has stopped" banner.
    var budiStops = false
    /// Agus's phone last sent a position 6 minutes ago.
    var agusIsOffline = false
    /// After 6 seconds Agus gets a new route, with the same stops or another destination.
    var agusChangesRoute: RouteChange?

    /// How the simulated leader changes the route.
    enum RouteChange {
        case sameStops, newDestination
    }

    /// Moves the cars until the task is cancelled.
    func Run() async {
        var second = startSecond
        while Task.isCancelled == false {
            let agusDistance = 400 + Double(second) * Self.metresPerSecond
            await Move(
                SampleTrip.agusID,
                metresAlongRoute: agusDistance,
                recordedAt: agusIsOffline ? .now.addingTimeInterval(-360) : .now
            )
            if second - startSecond == Self.routeChangeSecond { await ChangeRoute() }
            let hasBudiStopped = budiStops && second - startSecond >= Self.budiStopSecond
            let budiSecond = hasBudiStopped ? startSecond + Self.budiStopSecond : second
            await Move(
                SampleTrip.budiID,
                metresAlongRoute: 150 + Double(budiSecond) * Self.metresPerSecond,
                isStopped: hasBudiStopped,
                sideways: budiLeavesRoute ? 150 : 0
            )
            if budiLeavesRoute, second - startSecond == Int(FormationAlertDetector.holdTime) {
                try? await tripService.SetAlert(.offRoute, participantID: SampleTrip.budiID, tripID: SampleTrip.tripID)
            }
            if agusDistance >= Self.DistanceAlongRoute(toPointAt: SampleTrip.checkpointRouteIndex) {
                try? await tripService.AdvanceCheckpoint(to: 2, tripID: SampleTrip.tripID, by: SampleTrip.agusID)
            }
            second += 1
            try? await Task.sleep(for: interval)
        }
    }

    private func ChangeRoute() async {
        guard let agusChangesRoute else { return }
        var waypoints = SampleTrip.plan.waypoints
        if agusChangesRoute == .newDestination, let last = waypoints.indices.last {
            waypoints[last].name = "Pakuwon city mall"
        }
        let plan = TripPlan(waypoints: waypoints, polyline: SampleTrip.plan.polyline)
        try? await tripService.SaveRoute(plan, tripID: SampleTrip.tripID, by: SampleTrip.agusID)
    }

    /// Moves a car to `distance` metres along the route, and `sideways` metres to the left of it.
    private func Move(
        _ participantID: UUID,
        metresAlongRoute distance: Double,
        isStopped: Bool = false,
        sideways: Double = 0,
        recordedAt: Date = .now
    ) async {
        let reachedTheEnd = distance >= Self.DistanceAlongRoute(toPointAt: SampleTrip.plan.polyline.count - 1)
        let hasArrived = reachedTheEnd || isStopped
        let coordinate = Self.Beside(metresAlongRoute: distance, sideways: sideways)
        let update = LocationUpdate(
            coordinate: coordinate,
            speedKmh: hasArrived ? 0 : Self.metresPerSecond * 3.6,
            motionState: hasArrived ? .stopped : .driving,
            recordedAt: recordedAt
        )
        try? await tripService.UpdateLocation(update, participantID: participantID, tripID: SampleTrip.tripID)
    }

    /// The start second at which Budi, with `budiStops`, parks `metres` before the destination's point, as if in the
    /// far corner of a big mall's car park. Agus, ahead of him, has arrived by then.
    static func StartSecond(budiParksMetresBeforeTheEnd metres: Double) -> Int {
        let end = DistanceAlongRoute(toPointAt: SampleTrip.plan.polyline.count - 1)
        return Int(((end - metres - 150) / metresPerSecond).rounded()) - budiStopSecond
    }

    /// Metres along the sample route from the start point to its point at `index`.
    static func DistanceAlongRoute(toPointAt index: Int) -> Double {
        let route = Array(SampleTrip.plan.polyline.prefix(index + 1))
        return zip(route, route.dropFirst()).reduce(0) { $0 + $1.0.Distance(to: $1.1) }
    }

    /// The point `sideways` metres to the left of the sample route, at right angles to it, `distance` metres along.
    static func Beside(metresAlongRoute distance: Double, sideways: Double) -> Coordinate {
        let here = Position(metresAlongRoute: distance)
        guard sideways != 0 else { return here }
        let ahead = Position(metresAlongRoute: distance + 10)
        let metresPerDegree = 111_320.0
        let metresPerDegreeEast = metresPerDegree * cos(here.latitude * .pi / 180)
        let east = (ahead.longitude - here.longitude) * metresPerDegreeEast
        let north = (ahead.latitude - here.latitude) * metresPerDegree
        let length = (east * east + north * north).squareRoot()
        guard length > 0 else { return here }
        return Coordinate(
            latitude: here.latitude + east / length * sideways / metresPerDegree,
            longitude: here.longitude - north / length * sideways / metresPerDegreeEast
        )
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
