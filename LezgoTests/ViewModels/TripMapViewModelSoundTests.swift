//
//  TripMapViewModelSoundTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 09/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// Voice guidance, alert sounds and the mute button on the trip map (`specs/UserStories.md` → US-06, "Sound").
struct TripMapViewModelSoundTests {
    private typealias Fixtures = TripMapFixtures

    /// Each test gets its own preferences, so a mute saved by one test never reaches another.
    private let preferences: UserDefaults

    init() throws {
        preferences = try #require(UserDefaults(suiteName: "TripMapViewModelSoundTests.\(UUID().uuidString)"))
    }

    private func MakeViewModel(states: [TripState], speaker: MockNavigationSpeaker) -> TripMapViewModel {
        TripMapViewModel(
            tripID: Fixtures.tripID,
            myParticipantID: Fixtures.budiID,
            tripService: MockTripService(states: states),
            navigator: MockTripMapNavigator(results: [.success(Fixtures.Guidance())]),
            streetNameService: MockStreetNameService(),
            speaker: speaker,
            preferences: preferences,
            clock: { Fixtures.now }
        )
    }

    /// The trip with Citra online and off the route, so Budi's phone shows "Citra has gone out of route".
    private func StateWithCitraOffRoute() -> TripState {
        var state = Fixtures.State()
        if let citra = state.participants.firstIndex(where: { $0.id == Fixtures.citraID }) {
            state.participants[citra].alert = .offRoute
        }
        return state
    }

    @Test func TheNextTurnIsSpoken() async {
        let speaker = MockNavigationSpeaker()
        let viewModel = MakeViewModel(states: [Fixtures.State()], speaker: speaker)

        await viewModel.Start()

        #expect(speaker.announcements == [.turn(instruction: "Turn right", meters: 200)])
    }

    @Test func TheSameTurnOnTheNextUpdateIsNotSpokenAgain() async {
        let speaker = MockNavigationSpeaker()
        let viewModel = MakeViewModel(states: [Fixtures.State(), Fixtures.State()], speaker: speaker)

        await viewModel.Start()

        #expect(speaker.announcements == [.turn(instruction: "Turn right", meters: 200)])
    }

    @Test func AnotherCarOffTheRoutePlaysTheAlertBeforeTheTurn() async throws {
        let speaker = MockNavigationSpeaker()
        let viewModel = MakeViewModel(states: [StateWithCitraOffRoute()], speaker: speaker)

        await viewModel.Start()

        let banner = try #require(viewModel.alertBanner)
        #expect(speaker.announcements == [
            .alert(message: String(localized: banner.message)),
            .turn(instruction: "Turn right", meters: 200)
        ])
    }

    @Test func SoundIsOnByDefault() {
        let viewModel = MakeViewModel(states: [], speaker: MockNavigationSpeaker())

        #expect(viewModel.isSoundMuted == false)
    }

    @Test func MutingStopsTheVoiceAndIsRemembered() {
        let speaker = MockNavigationSpeaker()
        let viewModel = MakeViewModel(states: [], speaker: speaker)

        viewModel.ToggleSound()

        #expect(viewModel.isSoundMuted)
        #expect(speaker.stopCount == 1)
        #expect(MakeViewModel(states: [], speaker: MockNavigationSpeaker()).isSoundMuted)
    }

    @Test func AMutedMapSaysNothing() async {
        let speaker = MockNavigationSpeaker()
        MakeViewModel(states: [], speaker: MockNavigationSpeaker()).ToggleSound()
        let viewModel = MakeViewModel(states: [StateWithCitraOffRoute()], speaker: speaker)

        await viewModel.Start()

        #expect(speaker.announcements.isEmpty)
    }

    @Test func UnmutingTurnsTheSoundBackOn() {
        let viewModel = MakeViewModel(states: [], speaker: MockNavigationSpeaker())
        viewModel.ToggleSound()

        viewModel.ToggleSound()

        #expect(viewModel.isSoundMuted == false)
    }
}
