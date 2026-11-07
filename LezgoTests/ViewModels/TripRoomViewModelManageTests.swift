//
//  TripRoomViewModelManageTests.swift
//  LezgoTests
//
//  Created by Oky Faishal on 06/11/26.
//

import Foundation
import Testing
@testable import Lezgo

/// The menu that opens when an avatar is held (US-04, "Manage participants"; US-05).
@MainActor
struct TripRoomViewModelManageTests {
    private func OpenRoom(me: UUID, service: InMemoryTripService? = nil) -> TripRoomViewModel {
        TripRoomViewModel(
            tripService: service ?? SampleTrip.Service(status: .lobby, me: me),
            tripID: SampleTrip.tripID,
            myParticipantID: me,
            initialState: SampleTrip.State(status: .lobby)
        )
    }

    private func Car(_ id: UUID) throws -> Participant {
        try #require(SampleTrip.State(status: .lobby).participants.first { $0.id == id })
    }

    @Test func LeaderHoldingAMemberCanHandOverEditAndRemove() throws {
        let viewModel = OpenRoom(me: SampleTrip.agusID)

        let actions = viewModel.ManagementActions(for: try Car(SampleTrip.budiID))

        #expect(actions == [.setLeader, .editDetails, .remove])
    }

    @Test func LeaderHoldingTheirOwnAvatarCanOnlyEdit() throws {
        let viewModel = OpenRoom(me: SampleTrip.agusID)

        #expect(viewModel.ManagementActions(for: try Car(SampleTrip.agusID)) == [.editDetails])
    }

    @Test func MemberHoldingTheirOwnAvatarCanOnlyEdit() throws {
        let viewModel = OpenRoom(me: SampleTrip.budiID)

        #expect(viewModel.ManagementActions(for: try Car(SampleTrip.budiID)) == [.editDetails])
    }

    @Test func MemberHoldingSomeoneElseGetsNoMenu() throws {
        let viewModel = OpenRoom(me: SampleTrip.budiID)

        #expect(viewModel.ManagementActions(for: try Car(SampleTrip.agusID)).isEmpty)
        #expect(viewModel.ManagementActions(for: try Car(SampleTrip.citraID)).isEmpty)
    }

    @Test func RemovingACarTakesItOutOfTheTrip() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        let viewModel = OpenRoom(me: SampleTrip.agusID, service: service)

        await viewModel.RemoveFromTrip(try Car(SampleTrip.citraID))

        let state = try await service.FetchTrip(tripID: SampleTrip.tripID)
        #expect(state.participants.contains { $0.id == SampleTrip.citraID } == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func FailedRemovalShowsAReadableMessage() async throws {
        let service = SampleTrip.Service(status: .lobby, me: SampleTrip.agusID)
        service.simulatedFailure = .noNetwork
        let viewModel = OpenRoom(me: SampleTrip.agusID, service: service)

        await viewModel.RemoveFromTrip(try Car(SampleTrip.citraID))

        #expect(viewModel.errorMessage == String(localized: TripServiceError.noNetwork.message))
    }
}
