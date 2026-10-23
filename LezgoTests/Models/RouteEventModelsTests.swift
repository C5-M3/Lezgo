//
//  RouteEventModelsTests.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 23/10/26.
//


import CoreLocation
import Foundation
import Testing
@testable import LezgoApp

@Suite("RouteEventModels Tests")
struct RouteEventModelsTests {

    @Test func RoutePointCoordinateConversionAndID() {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let point = RoutePoint(latitude: -7.2575, longitude: 112.7521, timestamp: timestamp)

        #expect(point.coordinate.latitude == -7.2575)
        #expect(point.coordinate.longitude == 112.7521)
        #expect(!point.id.isEmpty)
    }

    @Test func RouteDataEncodesAndDecodesLargePayloadWithoutOrderLoss() throws {
        let baseDate = Date()
        var originalPoints: [RoutePoint] = []
        originalPoints.reserveCapacity(2_000)

        for index in 0..<2_000 {
            originalPoints.append(
                RoutePoint(
                    latitude: -7.0 + (Double(index) * 0.0001),
                    longitude: 112.0 + (Double(index) * 0.0001),
                    timestamp: baseDate.addingTimeInterval(Double(index))
                )
            )
        }

        let routeData = try RouteData(
            id: UUID().uuidString,
            sessionID: "SESSION-123",
            routeVersion: 1,
            plannedPoints: originalPoints,
            createdAt: baseDate,
            updatedAt: baseDate
        )

        let decodedPoints = try routeData.DecodePlannedPoints()

        #expect(decodedPoints.count == 2_000)
        #expect(decodedPoints.first?.latitude == originalPoints.first?.latitude)
        #expect(decodedPoints.last?.latitude == originalPoints.last?.latitude)
        #expect(decodedPoints[1_000].longitude == originalPoints[1_000].longitude)
    }

    @Test func TripEventSerializesToAPNsInteractivePayload() throws {
        let event = TripEvent(
            id: UUID().uuidString,
            sessionID: "SESSION-123",
            participantID: "USER-1",
            participantName: "Farrell",
            eventType: .leftRoute,
            message: "Driver deviated from the route.",
            latitude: -7.28,
            longitude: 112.74,
            createdAt: Date()
        )

        let payloadData = try JSONEncoder().encode(event)
        let jsonObject = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any]

        #expect(jsonObject != nil)
        #expect(jsonObject?["participantName"] as? String == "Farrell")
        #expect(jsonObject?["eventType"] as? String == "leftRoute")
    }

    @Test func WaypointRecapSummaryTracksVisitedStatus() {
        let visitedCheckpoint = WaypointRecapSummary(
            id: "WP-1",
            name: "Rest Area KM 26",
            orderIndex: 0,
            waypointType: .checkpoint,
            isVisited: true
        )

        let missedCheckpoint = WaypointRecapSummary(
            id: "WP-2",
            name: "Gas Station KM 50",
            orderIndex: 1,
            waypointType: .checkpoint,
            isVisited: false
        )

        #expect(visitedCheckpoint.isVisited == true)
        #expect(missedCheckpoint.isVisited == false)
    }

    @Test func TripRecapDataFormatsDurationAndDistanceCorrectly() {
        let recap = TripRecapData(
            id: UUID().uuidString,
            sessionID: "SESSION-999",
            originName: "Surabaya",
            destinationName: "Malang",
            totalDistanceKm: 94.67,
            totalDurationSeconds: 5_520, // 1 hour, 32 minutes
            waypointsSummary: [],
            fleetMembers: [],
            routePoints: []
        )

        #expect(recap.formattedDistance == "94.7 km")
        #expect(recap.formattedDuration == "1 hour 32 mins")
    }
}
