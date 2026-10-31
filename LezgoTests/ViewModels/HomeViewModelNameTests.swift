//
//  HomeViewModelNameTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 31/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// Joining from Home uses the name saved on this phone, once I typed one in the Trip Room (`specs/UserStories.md` →
/// US-04).
@MainActor
struct HomeViewModelNameTests {
    private func MakeHome(_ profiles: FakeProfileStorage) -> HomeViewModel {
        HomeViewModel(
            mapService: MockMapService(),
            searchService: MockLocationSearchService(),
            activeTripStorage: FakeActiveTripStorage(),
            profileStorage: profiles
        )
    }

    @Test func JoiningUsesTheSavedName() async throws {
        let service = SampleTrip.Service(status: .lobby, me: UUID())
        let home = MakeHome(FakeProfileStorage(ParticipantProfile(displayName: "Nathan", carDescription: "")))

        await home.JoinTrip(roomCode: SampleTrip.roomCode, tripService: service)

        let session = try #require(home.activeTripSession)
        let me = session.state.participants.first { $0.id == session.myParticipantID }
        #expect(me?.displayName == "Nathan")
    }
}
