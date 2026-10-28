//
//  RoutingServiceTests.swift
//  LezgoTests
//
//  Created by Farrell Sudjatmiko on 28/10/26.
//

import CoreLocation
import Foundation
import MapKit
import Testing
@testable import Lezgo

struct RoutingServiceTests {
    @Test func CalculateMultiStopLegsThrowsWhenFewerThanTwoPoints() async {
        let service = RoutingService()

        // 0 points
        await #expect(throws: NSError.self) {
            try await service.calculateMultiStopLegs(points: [])
        }

        // 1 point
        let singlePoint = RoutePoint(
            name: "Origin",
            subtitle: "Start point",
            coordinate: CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)
        )
        await #expect(throws: NSError.self) {
            try await service.calculateMultiStopLegs(points: [singlePoint])
        }
    }

    @Test func RouteOptionEquatableAndInitialization() {
        let id = UUID()
        let polyline = MKPolyline()
        let option1 = RouteOption(
            id: id,
            name: "Fastest",
            polylines: [polyline],
            combinedPolyline: polyline,
            totalDistance: 12500,
            totalDuration: 1800
        )
        let option2 = RouteOption(
            id: id,
            name: "Alternative",
            polylines: [polyline],
            combinedPolyline: polyline,
            totalDistance: 15000,
            totalDuration: 2100
        )
        let option3 = RouteOption(
            id: UUID(),
            name: "Fastest",
            polylines: [polyline],
            combinedPolyline: polyline,
            totalDistance: 12500,
            totalDuration: 1800
        )

        #expect(option1 == option2)
        #expect(option1 != option3)
        #expect(option1.name == "Fastest")
        #expect(option1.totalDistance == 12500)
        #expect(option1.totalDuration == 1800)
    }

    @Test func RouteLegSelectedRouteFallbackWhenIndexOutOfBounds() {
        let id = UUID()
        let route = MKRoute()
        let leg = RouteLeg(
            id: id,
            legIndex: 0,
            fromName: "Point A",
            toName: "Point B",
            routes: [route],
            selectedRouteIndex: 5 // out of bounds
        )

        #expect(leg.selectedRoute == route)
    }

    @Test func RouteLegEquatableComparesIdAndSelectedRouteIndex() {
        let id = UUID()
        let route = MKRoute()
        var leg1 = RouteLeg(
            id: id,
            legIndex: 0,
            fromName: "Point A",
            toName: "Point B",
            routes: [route],
            selectedRouteIndex: 0
        )
        let leg2 = RouteLeg(
            id: id,
            legIndex: 0,
            fromName: "Point A",
            toName: "Point B",
            routes: [route],
            selectedRouteIndex: 0
        )

        #expect(leg1 == leg2)

        leg1.selectedRouteIndex = 1
        #expect(leg1 != leg2)

        let legWithDifferentId = RouteLeg(
            id: UUID(),
            legIndex: 0,
            fromName: "Point A",
            toName: "Point B",
            routes: [route],
            selectedRouteIndex: 0
        )
        #expect(leg2 != legWithDifferentId)
    }
}
