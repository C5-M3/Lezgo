//
//  TripRecordMapperTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 26/10/26.
//

import CloudKit
import Foundation
import Testing
@testable import Lezgo

struct TripRecordMapperTests {
    // MARK: Trip

    @Test(arguments: TripStatus.allCases)
    func TripSurvivesTheRoundTrip(status: TripStatus) throws {
        var trip = TripFixtures.Trip(currentWaypointIndex: 2)
        trip.status = status
        trip.endedAt = TripFixtures.now.addingTimeInterval(60)

        let record = TripRecordMapper.MakeRecord(trip)

        #expect(try TripRecordMapper.MakeTrip(from: record) == trip)
    }

    @Test func TripWithoutStartAndEndSurvivesTheRoundTrip() throws {
        var trip = TripFixtures.Trip()
        trip.status = .lobby
        trip.startedAt = nil
        trip.endedAt = nil

        #expect(try TripRecordMapper.MakeTrip(from: TripRecordMapper.MakeRecord(trip)) == trip)
    }

    @Test func TripRecordUsesTheSchemaNames() {
        let record = TripRecordMapper.MakeRecord(TripFixtures.Trip())

        #expect(record.recordType == "Trip")
        #expect(record.recordID.recordName == TripFixtures.tripID.uuidString)
        #expect(record["roomCode"] as? String == "897654")
        #expect(record["status"] as? String == "IN_TRIP")
        #expect(record["leaderParticipantID"] as? String == TripFixtures.agusID.uuidString)
    }

    @Test func TripWithAnUnknownStatusIsInvalid() {
        let record = TripRecordMapper.MakeRecord(TripFixtures.Trip())
        record["status"] = "PAUSED"

        #expect(throws: InvalidTripRecord(recordType: "Trip", field: "status")) {
            try TripRecordMapper.MakeTrip(from: record)
        }
    }

    @Test func TripWithoutARoomCodeIsInvalid() {
        let record = TripRecordMapper.MakeRecord(TripFixtures.Trip())
        record["roomCode"] = nil

        #expect(throws: InvalidTripRecord(recordType: "Trip", field: "roomCode")) {
            try TripRecordMapper.MakeTrip(from: record)
        }
    }

    // MARK: Waypoint

    @Test(arguments: WaypointKind.allCases)
    func WaypointSurvivesTheRoundTrip(kind: WaypointKind) throws {
        let waypoint = TripFixtures.Waypoint(orderIndex: 3, kind: kind)

        #expect(try TripRecordMapper.MakeWaypoint(from: TripRecordMapper.MakeRecord(waypoint)) == waypoint)
    }

    @Test func WaypointIsDeletedWithItsTrip() throws {
        let record = TripRecordMapper.MakeRecord(TripFixtures.Waypoint(orderIndex: 1))

        let reference = try #require(record["tripID"] as? CKRecord.Reference)
        #expect(reference.recordID.recordName == TripFixtures.tripID.uuidString)
        #expect(reference.action == .deleteSelf)
    }

    @Test func WaypointStoresLatitudeAndLongitudeSeparately() {
        let record = TripRecordMapper.MakeRecord(TripFixtures.Waypoint(orderIndex: 1))

        #expect(record["latitude"] as? Double == TripFixtures.ciputraWorld.latitude)
        #expect(record["longitude"] as? Double == TripFixtures.ciputraWorld.longitude)
    }

    // MARK: Participant

    @Test(arguments: FormationAlert.allCases)
    func ParticipantSurvivesTheRoundTrip(alert: FormationAlert) throws {
        var participant = TripFixtures.Participant()
        participant.alert = alert
        participant.motionState = .stopped

        #expect(try TripRecordMapper.MakeParticipant(from: TripRecordMapper.MakeRecord(participant)) == participant)
    }

    @Test func ParticipantWithoutALocationYetSurvivesTheRoundTrip() throws {
        var participant = TripFixtures.Participant()
        participant.coordinate = nil

        let record = TripRecordMapper.MakeRecord(participant)

        #expect(record["latitude"] == nil)
        #expect(try TripRecordMapper.MakeParticipant(from: record) == participant)
    }

    @Test func ParticipantWithAVeryLongNameKeepsItWhole() throws {
        var participant = TripFixtures.Participant()
        participant.displayName = String(repeating: "Budi Santoso ", count: 40)

        #expect(try TripRecordMapper.MakeParticipant(from: TripRecordMapper.MakeRecord(participant)) == participant)
    }

    @Test func ParticipantIsDeletedWithItsTrip() throws {
        let record = TripRecordMapper.MakeRecord(TripFixtures.Participant())

        let reference = try #require(record["tripID"] as? CKRecord.Reference)
        #expect(reference.action == .deleteSelf)
    }

    // MARK: Route

    @Test func RouteSurvivesTheRoundTrip() throws {
        let route = Route(
            id: UUID(),
            tripID: TripFixtures.tripID,
            version: 4,
            polyline: [TripFixtures.tunjunganPlaza, TripFixtures.ciputraWorld, TripFixtures.pakuwonMall]
        )

        #expect(try TripRecordMapper.MakeRoute(from: TripRecordMapper.MakeRecord(route)) == route)
    }

    @Test func EmptyRouteSurvivesTheRoundTrip() throws {
        let route = Route(id: UUID(), tripID: TripFixtures.tripID, version: 1, polyline: [])

        #expect(try TripRecordMapper.MakeRoute(from: TripRecordMapper.MakeRecord(route)) == route)
    }

    @Test func LongRouteFitsInOneRecord() throws {
        // A long day trip has a few thousand road points; a record holds at most 1 MB.
        let polyline = (0..<10_000).map { index in
            Coordinate(latitude: -7 - Double(index) * 0.0001, longitude: 112 + Double(index) * 0.0001)
        }
        let route = Route(id: UUID(), tripID: TripFixtures.tripID, version: 1, polyline: polyline)

        let record = TripRecordMapper.MakeRecord(route)

        let bytes = try #require(record["polyline"] as? Data)
        #expect(bytes.count < 1_000_000)
        #expect(try TripRecordMapper.MakeRoute(from: record) == route)
    }

    @Test func RouteWithBrokenPolylineBytesIsInvalid() {
        let route = Route(id: UUID(), tripID: TripFixtures.tripID, version: 1, polyline: [])
        let record = TripRecordMapper.MakeRecord(route)
        record["polyline"] = Data([1, 2, 3])

        #expect(throws: InvalidTripRecord(recordType: "Route", field: "polyline")) {
            try TripRecordMapper.MakeRoute(from: record)
        }
    }

    // MARK: Wrong record type

    @Test func RecordOfAnotherTypeIsInvalid() {
        let record = TripRecordMapper.MakeRecord(TripFixtures.Participant())

        #expect(throws: InvalidTripRecord.self) {
            try TripRecordMapper.MakeTrip(from: record)
        }
    }
}
