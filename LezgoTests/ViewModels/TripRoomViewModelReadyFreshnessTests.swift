//
//  TripRoomViewModelReadyFreshnessTests.swift
//  LezgoTests
//

import Foundation
import Testing
@testable import Lezgo

/// A car that lost its signal stops showing as ready soon, long before the map calls it offline
/// (`specs/UserStories.md` → US-04, "Ready").
@MainActor
struct TripRoomViewModelReadyFreshnessTests {
    @Test func IsParticipantNotReadySoonAfterTheSignalIsLost() throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: SampleTrip.State(status: .lobby)
        )
        let startPoint = try #require(viewModel.startPoint)
        let now = Date.now

        func AtTheStartPoint(lastSeen secondsAgo: TimeInterval) -> Participant {
            Participant(
                id: UUID(),
                tripID: SampleTrip.tripID,
                userRecordID: "user_signal",
                displayName: "Driver",
                carDescription: "Car",
                coordinate: startPoint.coordinate,
                speedKmh: 0,
                motionState: .stopped,
                alert: .none,
                lastSeenAt: now.addingTimeInterval(-secondsAgo)
            )
        }

        // Still sending: a few seconds between two updates is normal.
        #expect(viewModel.IsParticipantReady(AtTheStartPoint(lastSeen: 5), at: now))
        // Airplane mode: no update for 30 seconds, long before the 2 minutes that mark a car offline on the map.
        #expect(viewModel.IsParticipantReady(AtTheStartPoint(lastSeen: 30), at: now) == false)
        #expect(AtTheStartPoint(lastSeen: 30).IsOnline(at: now))
    }
}
