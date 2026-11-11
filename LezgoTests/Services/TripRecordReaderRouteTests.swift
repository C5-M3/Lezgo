//
//  TripRecordReaderRouteTests.swift
//  LezgoTests
//
//  Created by oky faishal on 10/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// How the live service reads the stops after a route change while CloudKit's query index lags behind (#291).
struct TripRecordReaderRouteTests {
    let server = FakeCloudServer()
    let agus: LiveTripService
    let reader: TripRecordReader

    init() {
        agus = LiveTripService(database: FakeCloudDatabase(server: server, userRecordName: "_agus0001"))
        reader = TripRecordReader(database: FakeCloudDatabase(server: server, userRecordName: "_reader"))
    }

    /// Saves the new route a minute after the last change, as the server stamps each save with its own time.
    private func SaveNewRoute(_ session: TripSession) async throws {
        server.AdvanceClock(by: 60)
        try await agus.SaveRoute(
            TripPlanFixtures.ciputraToPakuwonCity,
            tripID: session.state.trip.id,
            by: session.myParticipantID
        )
    }

    /// The query that looks for the old stops ran before it could see them, so they were never deleted.
    @Test func StopsOfAnOlderRouteAreNotShown() async throws {
        server.FreezeQueryIndex()
        let session = try await agus.CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)
        try await SaveNewRoute(session)
        server.CatchUpQueryIndex()

        let state = try await reader.LoadState(tripID: session.state.trip.id)

        #expect(state.waypoints.map(\.name) == ["Ciputra World", "Pakuwon city mall"])
    }

    /// A poll that cannot see the new stops yet keeps the route it had, and the next poll reads them again.
    @Test func RouteNotInTheQueryYetIsReadAgainOnTheNextPoll() async throws {
        let session = try await agus.CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)
        let before = try await reader.LoadState(tripID: session.state.trip.id)
        server.FreezeQueryIndex()
        try await SaveNewRoute(session)

        let lagging = try await reader.LoadState(tripID: session.state.trip.id, reusing: before)
        server.CatchUpQueryIndex()
        let caughtUp = try await reader.LoadState(tripID: session.state.trip.id, reusing: lagging)

        #expect(lagging.waypoints == before.waypoints)
        #expect(caughtUp.waypoints.map(\.name) == ["Ciputra World", "Pakuwon city mall"])
        #expect(caughtUp.route?.version == 2)
    }

    /// A destination that did not move keeps its record, and with it every "I've Arrived" saved for it. The save
    /// writes it again, so the server stamps it with the new route's time, not the time it was first created.
    @Test func DestinationThatKeepsItsRecordIsStillShown() async throws {
        let session = try await agus.CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)
        let destinationID = try #require(session.state.waypoints.last?.id)
        try await SaveNewRoute(session)

        let state = try await reader.LoadState(tripID: session.state.trip.id)

        #expect(state.waypoints.last?.id == destinationID)
        #expect(state.waypoints.map(\.orderIndex) == [0, 1])
    }

    /// Two changes in a row, none of the old stops deleted: only the last route's stops are shown.
    @Test func OnlyTheLastOfSeveralRoutesIsShown() async throws {
        server.FreezeQueryIndex()
        let session = try await agus.CreateTrip(plan: TripPlanFixtures.tunjunganToPakuwon, profile: nil)
        try await SaveNewRoute(session)
        server.AdvanceClock(by: 60)
        try await agus.SaveRoute(
            TripPlanFixtures.tunjunganToPakuwon,
            tripID: session.state.trip.id,
            by: session.myParticipantID
        )
        server.CatchUpQueryIndex()

        let state = try await reader.LoadState(tripID: session.state.trip.id)

        #expect(state.route?.version == 3)
        #expect(state.waypoints.map(\.name) == ["Tunjungan Plaza", "Ciputra World", "Pakuwon mall"])
    }
}
