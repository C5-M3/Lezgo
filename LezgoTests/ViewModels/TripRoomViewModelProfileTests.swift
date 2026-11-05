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

    @Test func ChosenColorIsSavedAndRemembered() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.budiID)
        let profiles = FakeProfileStorage()
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            initialState: SampleTrip.State(status: .lobby),
            profileStorage: profiles
        )

        await viewModel.SaveProfile(displayName: "Budi", carDescription: "White Avanza", avatarColor: .blue)

        let budi = try await service.FetchTrip(tripID: SampleTrip.tripID).participants
            .first { $0.id == SampleTrip.budiID }
        #expect(budi?.avatarColor == .blue)
        #expect(profiles.savedProfile?.avatarColor == .blue)
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

/// The leader can fix anyone's name and car in the Trip Room; a member only their own.
@MainActor
struct TripRoomViewModelLeaderEditTests {
    private func OpenRoom(me: UUID, profiles: FakeProfileStorage = FakeProfileStorage()) -> TripRoomViewModel {
        TripRoomViewModel(
            tripService: SampleTrip.Service(status: .lobby, me: me),
            tripID: SampleTrip.tripID,
            myParticipantID: me,
            initialState: SampleTrip.State(status: .lobby),
            profileStorage: profiles
        )
    }

    private func Car(_ id: UUID) throws -> Participant {
        try #require(SampleTrip.State(status: .lobby).participants.first { $0.id == id })
    }

    @Test func MemberCannotEditSomeoneElse() throws {
        let viewModel = OpenRoom(me: SampleTrip.budiID)

        #expect(viewModel.CanEdit(participant: try Car(SampleTrip.agusID)) == false)
        #expect(viewModel.CanEdit(participant: try Car(SampleTrip.budiID)))
    }

    @Test func LeaderChangesAMembersDetails() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: SampleTrip.State(status: .lobby),
            profileStorage: FakeProfileStorage()
        )

        let didSave = await viewModel.SaveProfile(
            displayName: "Budi Santoso",
            carDescription: "Black Brio",
            avatarColor: .green,
            of: SampleTrip.budiID
        )

        #expect(didSave)
        let budi = try await service.FetchTrip(tripID: SampleTrip.tripID).participants
            .first { $0.id == SampleTrip.budiID }
        #expect(budi?.displayName == "Budi Santoso")
        #expect(budi?.carDescription == "Black Brio")
        #expect(budi?.avatarColor == .green)
    }

    @Test func MembersDetailsDoNotBecomeTheLeadersOwnProfile() async {
        // The saved profile is what this phone joins the next trip with.
        let profiles = FakeProfileStorage()
        let viewModel = OpenRoom(me: SampleTrip.agusID, profiles: profiles)

        await viewModel.SaveProfile(displayName: "Budi Santoso", carDescription: "", of: SampleTrip.budiID)

        #expect(profiles.savedProfile == nil)
    }

    @Test func LeadersOwnDetailsAreStillRemembered() async {
        let profiles = FakeProfileStorage()
        let viewModel = OpenRoom(me: SampleTrip.agusID, profiles: profiles)

        await viewModel.SaveProfile(displayName: "Agus", carDescription: "Red Jazz", of: SampleTrip.agusID)

        #expect(profiles.savedProfile == ParticipantProfile(displayName: "Agus", carDescription: "Red Jazz"))
    }

    @Test func MemberCannotSaveSomeoneElsesDetails() async throws {
        // A member's room can be out of date, or the row tap can race a handover; the check is here as well.
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.budiID)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            initialState: SampleTrip.State(status: .lobby),
            profileStorage: FakeProfileStorage()
        )

        let didSave = await viewModel.SaveProfile(displayName: "Hacked", carDescription: "", of: SampleTrip.agusID)

        #expect(didSave == false)
        let agus = try await service.FetchTrip(tripID: SampleTrip.tripID).participants
            .first { $0.id == SampleTrip.agusID }
        #expect(agus?.displayName != "Hacked")
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
