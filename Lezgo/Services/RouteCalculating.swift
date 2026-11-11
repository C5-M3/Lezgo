//
//  RouteCalculating.swift
//  Lezgo
//

import Foundation

/// Finds the driving legs between a start point and the stops, so tests can pass in a fake instead of MapKit.
protocol RouteCalculating {
    func calculateMultiStopLegs(points: [RoutePoint]) async throws -> [RouteLeg]
}
