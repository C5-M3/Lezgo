//
//  TripRoomViewModelReadyTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 31/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The Trip Room shares this phone's position, so the group sees who is at the start point
/// (`specs/UserStories.md` → US-04, "ready at startpoint"). Budi, a member, uses this phone.
@MainActor
struct TripRoomViewModelReadyTests {
    let service = SampleTrip.Service(status: .lobby, me: SampleTrip.budiID)
    let gps = MockLocationProvider()
    let sharer: LocationSharer

    init() {
        sharer = LocationSharer(
            tripService: service,
            locationProvider: gps,
            tripID: SampleTrip.tripID,
            participantID: SampleTrip.budiID,
            interval: .milliseconds(10)
        )
    }

    private func MakeRoom() -> TripRoomViewModel {
        TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            initialState: SampleTrip.State(status: .lobby),
            activeTripStorage: FakeActiveTripStorage(),
            locationSharer: sharer
        )
    }

    private func StartPoint() throws -> Coordinate {
        try #require(SampleTrip.State(status: .lobby).waypoints.first { $0.kind == .start }?.coordinate)
    }

    private func Me(in room: TripRoomViewModel) -> Participant? {
        room.participants.first { $0.id == SampleTrip.budiID }
    }

    /// Opens the room, sends one GPS reading, and waits until `isDone` (at most 2 seconds).
    private func Open(
        _ room: TripRoomViewModel,
        at coordinate: Coordinate,
        until isDone: () -> Bool
    ) async throws {
        let listen = Task { await room.Listen() }
        gps.Send(LocationReading(coordinate: coordinate, speedKmh: 0, recordedAt: .now))
        for _ in 0..<200 where isDone() == false {
            try await Task.sleep(for: .milliseconds(10))
        }
        listen.cancel()
        await listen.value
    }

    @Test func AtTheStartPointIAmReady() async throws {
        let room = MakeRoom()
        let start = try StartPoint()

        try await Open(room, at: start) { Me(in: room)?.coordinate == start }

        let me = try #require(Me(in: room))
        #expect(room.IsParticipantReady(me))
    }

    @Test func FarFromTheStartPointIAmNotReady() async throws {
        let room = MakeRoom()
        let farAway = Coordinate(latitude: -7.3500, longitude: 112.7387)

        try await Open(room, at: farAway) { Me(in: room)?.coordinate == farAway }

        let me = try #require(Me(in: room))
        #expect(me.coordinate == farAway)
        #expect(room.IsParticipantReady(me) == false)
    }

    @Test func LeavingTheRoomStopsSharing() async throws {
        let room = MakeRoom()
        let start = try StartPoint()
        try await Open(room, at: start) { sharer.sentCount > 0 }
        let sentWhenClosed = sharer.sentCount

        try await Task.sleep(for: .milliseconds(50))

        #expect(sharer.sentCount == sentWhenClosed)
    }

    @Test func RoomSaysWhenPreciseLocationIsOff() async throws {
        let room = MakeRoom()
        let listen = Task { await room.Listen() }
        var rough = LocationReading(coordinate: try StartPoint(), speedKmh: 0, recordedAt: .now)
        rough.isPrecise = false
        gps.Send(rough)
        for _ in 0..<200 where room.isLocationImprecise == false {
            try await Task.sleep(for: .milliseconds(10))
        }
        listen.cancel()
        await listen.value

        #expect(room.isLocationImprecise)
    }
}
