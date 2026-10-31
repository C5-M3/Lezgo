//
//  HomeViewModelNameTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 31/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// Home asks for my name once, so the group sees it instead of "Member 1d9d" (`specs/UserStories.md` → US-04).
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

    @Test func AsksForANameTheFirstTime() {
        let home = MakeHome(FakeProfileStorage())

        #expect(home.isAskingForName)
    }

    @Test func DoesNotAskAgainOnceANameIsSaved() {
        let home = MakeHome(FakeProfileStorage(ParticipantProfile(displayName: "Nathan", carDescription: "")))

        #expect(home.isAskingForName == false)
    }

    @Test func NameIsTrimmedAndRemembered() {
        let profiles = FakeProfileStorage()
        let home = MakeHome(profiles)

        let didSave = home.SaveName("  Nathan  ")

        #expect(didSave)
        #expect(home.isAskingForName == false)
        #expect(profiles.savedProfile?.displayName == "Nathan")
    }

    @Test func BlankNameIsNotSaved() {
        let profiles = FakeProfileStorage()
        let home = MakeHome(profiles)

        let didSave = home.SaveName("   ")

        #expect(didSave == false)
        #expect(home.isAskingForName)
        #expect(profiles.savedProfile == nil)
    }

    @Test func LongNameIsCutTo30Characters() {
        let profiles = FakeProfileStorage()
        let home = MakeHome(profiles)

        home.SaveName(String(repeating: "a", count: 45))

        #expect(profiles.savedProfile?.displayName.count == 30)
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
