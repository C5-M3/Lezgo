//
//  TripRoomViewModelNameTests.swift
//  LezgoTests
//
//  Created by Oky Faishal on 06/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The two checks of a unique name in Edit Profile: when the field is left, and on "Save" (US-04).
@MainActor
struct TripRoomViewModelNameTests {
    private func OpenRoom(me: UUID) -> TripRoomViewModel {
        TripRoomViewModel(
            tripService: SampleTrip.Service(status: .lobby, me: me),
            tripID: SampleTrip.tripID,
            myParticipantID: me,
            initialState: SampleTrip.State(status: .lobby)
        )
    }

    @Test func LeavingTheFieldFlagsANameAnotherCarHas() {
        let viewModel = OpenRoom(me: SampleTrip.budiID)

        #expect(viewModel.IsNameTaken("  agus ", for: SampleTrip.budiID) == true)
    }

    @Test func LeavingTheFieldAcceptsANewName() {
        let viewModel = OpenRoom(me: SampleTrip.budiID)

        #expect(viewModel.IsNameTaken("Budi Santoso", for: SampleTrip.budiID) == false)
    }

    @Test func KeepingMyOwnNameIsNotFlagged() {
        let viewModel = OpenRoom(me: SampleTrip.budiID)

        #expect(viewModel.IsNameTaken("BUDI", for: SampleTrip.budiID) == false)
    }

    @Test func SavingATakenNameFailsAndMarksTheField() async throws {
        let viewModel = OpenRoom(me: SampleTrip.budiID)

        let didSave = await viewModel.SaveProfile(displayName: "agus", carDescription: "White Brio")

        #expect(didSave == false)
        #expect(viewModel.isProfileNameTaken == true)
        #expect(viewModel.profileErrorMessage == String(localized: TripServiceError.nameAlreadyUsed.message))
    }

    @Test func SavingATakenNameDoesNotRememberItForTheNextTrip() async {
        let profiles = FakeProfileStorage()
        let viewModel = TripRoomViewModel(
            tripService: SampleTrip.Service(status: .lobby, me: SampleTrip.budiID),
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            initialState: SampleTrip.State(status: .lobby),
            profileStorage: profiles
        )

        await viewModel.SaveProfile(displayName: "Agus", carDescription: "White Brio")

        #expect(profiles.LoadProfile() == nil)
    }

    @Test func ASuccessfulSaveClearsTheMark() async {
        let viewModel = OpenRoom(me: SampleTrip.budiID)
        await viewModel.SaveProfile(displayName: "agus", carDescription: "White Brio")

        let didSave = await viewModel.SaveProfile(displayName: "Budi Santoso", carDescription: "White Brio")

        #expect(didSave == true)
        #expect(viewModel.isProfileNameTaken == false)
    }
}
