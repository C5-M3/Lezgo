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
}
