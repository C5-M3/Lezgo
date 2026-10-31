//
//  TripRoomViewModelProfileTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 27/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// Saving my profile from the edit sheet (#189).
@MainActor
struct TripRoomViewModelProfileTests {
    @Test func SaveProfileReportsSuccessSoTheSheetCanClose() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.budiID)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            initialState: SampleTrip.State(status: .lobby)
        )

        let didSave = await viewModel.SaveProfile(displayName: "Budi", carDescription: "White Avanza")

        #expect(didSave == true)
        #expect(viewModel.isSavingProfile == false)
        #expect(viewModel.profileErrorMessage == nil)
        let updated = try await service.FetchTrip(tripID: SampleTrip.tripID)
        let budi = try #require(updated.participants.first(where: { $0.id == SampleTrip.budiID }))
        #expect(budi.carDescription == "White Avanza")
    }

    @Test func SavedProfileIsRememberedForTheNextTrip() async {
        let profiles = FakeProfileStorage()
        let viewModel = TripRoomViewModel(
            tripService: SampleTrip.Service(status: .lobby, me: SampleTrip.budiID),
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            initialState: SampleTrip.State(status: .lobby),
            profileStorage: profiles
        )

        await viewModel.SaveProfile(displayName: "Budi", carDescription: "White Avanza")

        #expect(profiles.savedProfile == ParticipantProfile(displayName: "Budi", carDescription: "White Avanza"))
    }

    @Test func SaveProfileFailureKeepsTheSheetOpenWithAnError() async {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.budiID)
        service.simulatedFailure = .noNetwork
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            initialState: SampleTrip.State(status: .lobby)
        )

        let didSave = await viewModel.SaveProfile(displayName: "Budi", carDescription: "White Avanza")

        #expect(didSave == false)
        #expect(viewModel.isSavingProfile == false)
        #expect(viewModel.profileErrorMessage == String(localized: TripServiceError.noNetwork.message))
    }
}

/// Rows without a typed name are called "Leader", "Car 2", "Car 3" in the Trip Room.
@MainActor
struct TripRoomViewModelCarNameTests {
    @Test func UnnamedCarIsCalledByItsNumber() throws {
        var state = SampleTrip.State(status: .lobby)
        for index in state.participants.indices {
            state.participants[index].displayName = ""
        }
        let viewModel = TripRoomViewModel(
            tripService: SampleTrip.Service(status: .lobby, me: SampleTrip.agusID),
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: state
        )

        let leader = try #require(state.participants.first { $0.id == SampleTrip.agusID })
        let member = try #require(state.participants.first { $0.id == SampleTrip.budiID })
        #expect(viewModel.DisplayName(of: leader) == "Leader")
        #expect(viewModel.DisplayName(of: member).hasPrefix("Car "))
    }
}
