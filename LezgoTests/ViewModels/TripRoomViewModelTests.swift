//
//  TripRoomViewModelTests.swift
//  LezgoTests
//
//  Created by Oky Faishal on 25/10/26.
//

import Foundation
import Testing
@testable import Lezgo

@MainActor
struct TripRoomViewModelTests {
    @Test func InitialStateFromSampleTrip() {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let state = SampleTrip.State(status: .lobby)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: state
        )

        #expect(viewModel.roomCode == "897654")
        #expect(viewModel.waypoints.count == 3)
        #expect(viewModel.waypoints.first?.kind == .start)
        #expect(viewModel.waypoints.last?.kind == .destination)
        #expect(viewModel.participants.count == 3)
        #expect(viewModel.isCurrentUserLeader == true)
        #expect(viewModel.isSelectionMode == false)
        #expect(viewModel.tripStatus == .lobby)
    }

    @Test func StartTripUpdatesStatusWhenLeader() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let state = SampleTrip.State(status: .lobby)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: state
        )

        try await viewModel.StartTrip()

        let updated = try await service.FetchTrip(tripID: SampleTrip.tripID)
        #expect(updated.trip.status == .inTrip)
    }

    @Test func StartTripDoesNothingWhenNotLeader() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.budiID)
        let state = SampleTrip.State(status: .lobby)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            initialState: state
        )

        #expect(viewModel.isCurrentUserLeader == false)
        try await viewModel.StartTrip()

        let updated = try await service.FetchTrip(tripID: SampleTrip.tripID)
        #expect(updated.trip.status == .lobby)
    }

    @Test func SetLeaderTransfersLead() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let state = SampleTrip.State(status: .lobby)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: state
        )

        let budi = try #require(state.participants.first(where: { $0.id == SampleTrip.budiID }))
        try await viewModel.SetLeader(to: budi)

        let updated = try await service.FetchTrip(tripID: SampleTrip.tripID)
        #expect(updated.trip.leaderParticipantID == SampleTrip.budiID)
    }

    @Test func RemoveParticipantRemovesMember() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let state = SampleTrip.State(status: .lobby)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: state
        )

        try await viewModel.RemoveParticipant(id: SampleTrip.budiID)

        let updated = try await service.FetchTrip(tripID: SampleTrip.tripID)
        #expect(!updated.participants.contains(where: { $0.id == SampleTrip.budiID }))
    }

    @Test func RemoveSelectedParticipantsRemovesMembersAndExitsSelectionMode() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let state = SampleTrip.State(status: .lobby)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: state
        )

        viewModel.ToggleSelectionMode()
        viewModel.ToggleParticipantSelection(id: SampleTrip.budiID)
        #expect(viewModel.canRemove == true)

        try await viewModel.RemoveSelectedParticipants()

        #expect(viewModel.isSelectionMode == false)
        #expect(viewModel.selectedParticipantIds.isEmpty)
        let updated = try await service.FetchTrip(tripID: SampleTrip.tripID)
        #expect(!updated.participants.contains(where: { $0.id == SampleTrip.budiID }))
    }

    @Test func UpdateProfileUpdatesDisplayNameAndCar() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let state = SampleTrip.State(status: .lobby)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: state
        )

        try await viewModel.UpdateProfile(displayName: "Agus Baru", carDescription: "Innova Reborn")

        let updated = try await service.FetchTrip(tripID: SampleTrip.tripID)
        let agus = try #require(updated.participants.first(where: { $0.id == SampleTrip.agusID }))
        #expect(agus.displayName == "Agus Baru")
        #expect(agus.carDescription == "Innova Reborn")
    }

    @Test func LeaveTripEndsTripWhenLeader() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let state = SampleTrip.State(status: .lobby)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: state
        )

        try await viewModel.LeaveTrip()

        let updated = try await service.FetchTrip(tripID: SampleTrip.tripID)
        #expect(updated.trip.status == .cancelled)
    }

    @Test func LeaveTripExitsTripWhenMember() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.budiID)
        let state = SampleTrip.State(status: .lobby)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.budiID,
            initialState: state
        )

        try await viewModel.LeaveTrip()

        let updated = try await service.FetchTrip(tripID: SampleTrip.tripID)
        #expect(!updated.participants.contains(where: { $0.id == SampleTrip.budiID }))
    }

    @Test func ListenReceivesLiveUpdates() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID
        )

        let task = Task {
            await viewModel.Listen()
        }

        for _ in 0..<10 {
            if viewModel.state != nil { break }
            try await Task.sleep(for: .milliseconds(50))
        }

        #expect(viewModel.state != nil)
        #expect(viewModel.roomCode == "897654")

        task.cancel()
    }

    @Test func SelectionModeTogglesAndClearsSelection() {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let state = SampleTrip.State(status: .lobby)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: state
        )

        viewModel.ToggleSelectionMode()
        #expect(viewModel.isSelectionMode == true)

        viewModel.ToggleParticipantSelection(id: SampleTrip.budiID)
        #expect(viewModel.selectedParticipantIds.contains(SampleTrip.budiID))

        viewModel.ToggleSelectionMode()
        #expect(viewModel.isSelectionMode == false)
        #expect(viewModel.selectedParticipantIds.isEmpty)
    }

    @Test func LeaderCannotBeSelectedForRemoval() {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let state = SampleTrip.State(status: .lobby)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: state
        )

        viewModel.ToggleSelectionMode()
        viewModel.ToggleParticipantSelection(id: SampleTrip.agusID)

        #expect(viewModel.selectedParticipantIds.isEmpty)
    }

    @Test func SelectAllTogglesSelectionOfAllMembers() {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let state = SampleTrip.State(status: .lobby)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: state
        )

        viewModel.ToggleSelectionMode()
        #expect(viewModel.areAllMembersSelected == false)

        viewModel.SelectAll()
        #expect(viewModel.selectedParticipantIds.count == 2)
        #expect(viewModel.selectedParticipantIds.contains(SampleTrip.budiID))
        #expect(viewModel.selectedParticipantIds.contains(SampleTrip.citraID))
        #expect(!viewModel.selectedParticipantIds.contains(SampleTrip.agusID))
        #expect(viewModel.areAllMembersSelected == true)
        #expect(viewModel.canRemove == true)

        viewModel.SelectAll()
        #expect(viewModel.selectedParticipantIds.isEmpty)
        #expect(viewModel.areAllMembersSelected == false)
        #expect(viewModel.canRemove == false)
    }

    @Test func RemoveConfirmationTitleFormatsCorrectly() {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let state = SampleTrip.State(status: .lobby)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: state
        )

        #expect(viewModel.removeConfirmationTitle == "Remove participants from the trip?")

        viewModel.ToggleParticipantSelection(id: SampleTrip.budiID)
        #expect(viewModel.removeConfirmationTitle == "Remove Budi from the trip?")

        viewModel.ToggleParticipantSelection(id: SampleTrip.citraID)
        #expect(viewModel.removeConfirmationTitle == "Remove Budi and 1 other from the trip?")
    }

    @Test func FormattingTitlesAndPermissions() throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let state = SampleTrip.State(status: .lobby)
        let viewModel = TripRoomViewModel(
            tripService: service,
            tripID: SampleTrip.tripID,
            myParticipantID: SampleTrip.agusID,
            initialState: state
        )

        let agus = try #require(state.participants.first(where: { $0.id == SampleTrip.agusID }))
        let budi = try #require(state.participants.first(where: { $0.id == SampleTrip.budiID }))

        #expect(viewModel.RemoveParticipantConfirmationTitle(for: budi) == "Remove Budi from the trip?")
        #expect(viewModel.SetLeaderConfirmationTitle(for: budi) == "Set Budi as Trip Leader?")

        #expect(viewModel.CanKick(participant: budi) == true)
        #expect(viewModel.CanKick(participant: agus) == false)
        #expect(viewModel.CanSetLeader(participant: budi) == true)
        #expect(viewModel.CanSetLeader(participant: agus) == false)
        #expect(viewModel.CanEdit(participant: agus) == true)
        #expect(viewModel.CanEdit(participant: budi) == false)
        #expect(viewModel.IsLeader(participant: agus) == true)
        #expect(viewModel.IsLeader(participant: budi) == false)

        viewModel.ToggleSelectionMode()
        #expect(viewModel.CanKick(participant: budi) == false)
        #expect(viewModel.CanSetLeader(participant: budi) == false)
        #expect(viewModel.CanEdit(participant: agus) == false)
    }
}
