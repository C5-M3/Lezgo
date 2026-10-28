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
