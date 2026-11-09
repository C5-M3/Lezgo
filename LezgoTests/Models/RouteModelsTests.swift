//
//  RouteModelsTests.swift
//  LezgoTests
//
//  Created by Farrell Sudjatmiko on 28/10/26.
//

import CoreLocation
import Foundation
import Testing
@testable import Lezgo

struct RouteModelsTests {
    @Test func RoutePointInitializationAndEquality() {
        let id = UUID()
        let coord1 = CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)
        let coord2 = CLLocationCoordinate2D(latitude: -6.1754, longitude: 106.8272)

        let point1 = RoutePoint(id: id, name: "Jakarta", subtitle: "Capital", coordinate: coord1)
        let point2 = RoutePoint(id: id, name: "Different Name", subtitle: "Different Subtitle", coordinate: coord2)
        let point3 = RoutePoint(name: "Jakarta", subtitle: "Capital", coordinate: coord1)

        #expect(point1 == point2)
        #expect(point1 != point3)
        #expect(point1.name == "Jakarta")
        #expect(point1.subtitle == "Capital")
        #expect(point1.coordinate.latitude == coord1.latitude)
        #expect(point1.coordinate.longitude == coord1.longitude)
    }

    @Test func ActivePointSelectionId() {
        let start = ActivePointSelection.start
        let dest0 = ActivePointSelection.destination(index: 0)
        let dest1 = ActivePointSelection.destination(index: 1)

        #expect(start.id == "start")
        #expect(dest0.id == "destination_0")
        #expect(dest1.id == "destination_1")
    }

    @Test func ActivePointSelectionTitle() {
        let start = ActivePointSelection.start
        let dest0 = ActivePointSelection.destination(index: 0)
        let dest1 = ActivePointSelection.destination(index: 1)
        let dest2 = ActivePointSelection.destination(index: 2)

        #expect(start.title == "Starting Point")
        #expect(dest0.title == "Destination")
        #expect(dest1.title == "Stop 2")
        #expect(dest2.title == "Stop 3")
    }

    @Test func ActivePointSelectionEquatable() {
        #expect(ActivePointSelection.start == ActivePointSelection.start)
        #expect(ActivePointSelection.destination(index: 0) == ActivePointSelection.destination(index: 0))
        #expect(ActivePointSelection.destination(index: 0) != ActivePointSelection.destination(index: 1))
        #expect(ActivePointSelection.start != ActivePointSelection.destination(index: 0))
    }
}
