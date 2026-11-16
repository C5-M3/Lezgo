//
//  TripMapNavigator.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import Foundation

/// Works out the next turn and the time left for this phone's car.
///
/// The app uses `LiveTripMapNavigator` (MapKit directions), debug screens use `SimulatedTripMapNavigator`, and tests
/// use `MockTripMapNavigator`.
protocol TripMapNavigator {
    func Guidance(from position: Coordinate, along state: TripState) async throws -> TripMapGuidance

    /// The driving time from `position` to one point, such as the next checkpoint. Unlike `Guidance` it follows no
    /// route and keeps nothing for the next call.
    func TimeLeft(from position: Coordinate, to point: Coordinate) async throws -> Duration
}
