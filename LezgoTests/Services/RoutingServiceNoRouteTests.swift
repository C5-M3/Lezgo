//
//  RoutingServiceNoRouteTests.swift
//  LezgoTests
//

import CoreLocation
import Foundation
import MapKit
import Testing
@testable import Lezgo

/// "No drivable route" is told apart from every other failure, so the planner can say the stops are too far apart.
/// It is not a distance limit: MapKit finds a road from Surabaya to Medan, but none from Surabaya to Tokyo.
@MainActor
struct RoutingServiceNoRouteTests {
    private func Point(_ name: String, _ latitude: Double) -> RoutePoint {
        RoutePoint(name: name, subtitle: "", coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: 113))
    }

    private func Service(fetch: @escaping RoutingService.LegFetcher) -> RoutingService {
        RoutingService(debounce: .zero, fetchLegRoutes: fetch)
    }

    @Test func MapKitDirectionsNotFoundBecomesNoRoute() async {
        let notFound = NSError(
            domain: MKError.errorDomain,
            code: Int(MKError.Code.directionsNotFound.rawValue),
            userInfo: nil
        )
        let service = Service { _, _ in throw notFound }

        await #expect(throws: RoutingError.noRoute) {
            try await service.calculateMultiStopLegs(points: [Point("Surabaya", -7), Point("Tokyo", 35)])
        }
    }

    /// What MapKit really answers on iOS for Surabaya to Tokyo: not `directionsNotFound` but `serverFailure` (code 2),
    /// with the server's own problem detail ("NOT_REACHABLE") in the user info.
    @Test func ServerFailureWithADirectionsAnswerBecomesNoRoute() async {
        let notReachable = NSError(
            domain: MKError.errorDomain,
            code: Int(MKError.Code.serverFailure.rawValue),
            userInfo: ["MKErrorDirectionsErrorInfoKey": "NOT_REACHABLE"]
        )
        let service = Service { _, _ in throw notReachable }

        await #expect(throws: RoutingError.noRoute) {
            try await service.calculateMultiStopLegs(points: [Point("Surabaya", -7), Point("Tokyo", 35)])
        }
    }

    /// A server that could not be reached says nothing about the stops, so it must not be called "too far".
    @Test func ServerFailureWithoutADirectionsAnswerStaysAsItIs() async {
        let unreachableServer = NSError(
            domain: MKError.errorDomain,
            code: Int(MKError.Code.serverFailure.rawValue),
            userInfo: nil
        )
        let service = Service { _, _ in throw unreachableServer }

        await #expect(throws: NSError.self) {
            try await service.calculateMultiStopLegs(points: [Point("A", -7), Point("B", -8)])
        }
    }

    @Test func AnAnswerWithoutRoutesBecomesNoRoute() async {
        let service = Service { _, _ in [] }

        await #expect(throws: RoutingError.noRoute) {
            try await service.calculateMultiStopLegs(points: [Point("A", -7), Point("B", 35)])
        }
    }

    @Test func OtherFailuresStayAsTheyAre() async {
        let service = Service { _, _ in throw URLError(.notConnectedToInternet) }

        await #expect(throws: URLError.self) {
            try await service.calculateMultiStopLegs(points: [Point("A", -7), Point("B", -8)])
        }
    }
}
