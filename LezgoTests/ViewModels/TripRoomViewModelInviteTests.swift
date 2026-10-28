//
//  TripRoomViewModelInviteTests.swift
//  LezgoTests
//
//  Created by Oky Faishal on 28/10/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The invite sheet (US-04, "Invite"): the link, the share message, and when the room code can be copied or shared.
@MainActor
struct TripRoomViewModelInviteTests {
    @Test func InviteLinkCarriesTheRoomCode() {
        let viewModel = MakeViewModel(me: SampleTrip.budiID, state: SampleTrip.State(status: .lobby))

        #expect(viewModel.inviteURL.absoluteString == "lezgo://join?code=897654")
    }

    @Test func ShareMessageNamesTheRoomCode() {
        let viewModel = MakeViewModel(me: SampleTrip.budiID, state: SampleTrip.State(status: .lobby))

        #expect(viewModel.shareMessage.contains("897654"))
    }

    @Test(arguments: [SampleTrip.agusID, SampleTrip.budiID])
    func LeaderAndMembersCanShareOnceTheRoomCodeLoads(me: UUID) {
        let viewModel = MakeViewModel(me: me, state: SampleTrip.State(status: .lobby))

        #expect(viewModel.canShareInvite)
    }

    @Test func CannotShareBeforeTheRoomCodeLoads() {
        let viewModel = MakeViewModel(me: SampleTrip.budiID, state: nil)

        #expect(viewModel.canShareInvite == false)
    }

    @Test(arguments: ["", "12345", "1234567", "12a456"])
    func CannotShareARoomCodeThatIsNotSixDigits(roomCode: String) {
        var state = SampleTrip.State(status: .lobby)
        state.trip.roomCode = roomCode
        let viewModel = MakeViewModel(me: SampleTrip.budiID, state: state)

        #expect(viewModel.canShareInvite == false)
    }

    @Test func CanShareAfterTheFirstSnapshotArrives() async throws {
        let viewModel = MakeViewModel(me: SampleTrip.budiID, state: nil)
        let listening = Task { await viewModel.Listen() }
        defer { listening.cancel() }

        for _ in 0..<10 {
            if viewModel.state != nil { break }
            try await Task.sleep(for: .milliseconds(50))
        }

        #expect(viewModel.canShareInvite)
    }

    private func MakeViewModel(me participantID: UUID, state: TripState?) -> TripRoomViewModel {
        TripRoomViewModel(
            tripService: SampleTrip.Service(status: .lobby, me: participantID),
            tripID: SampleTrip.tripID,
            myParticipantID: participantID,
            initialState: state
        )
    }
}
