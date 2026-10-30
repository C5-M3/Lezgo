//
//  JoinTripViewModelTest.swift
//  LezgoTests
//
//  Created by Rizal Pratama on 26/10/26.
//

import Foundation
import Testing
@testable import Lezgo

@Suite("JoinTripViewModel Tests")
@MainActor
struct JoinTripViewModelTest {

    @Test("Initial state should be empty and invalid")
    func initialState() {
        let viewModel = JoinTripViewModel()
        #expect(viewModel.roomCode.isEmpty)
        #expect(viewModel.isValidCode == false)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isSubmitting == false)
        #expect(viewModel.joinedSession == nil)
    }

    @Test("Room code should truncate to maximum of 6 digits")
    func roomCodeLengthLimitation() {
        let viewModel = JoinTripViewModel()
        viewModel.roomCode = "12345678"
        #expect(viewModel.roomCode == "123456")
        #expect(viewModel.isValidCode == true)
    }

    @Test("Room code should only allow numeric characters and filter out non-numbers")
    func roomCodeNumbersOnly() {
        let viewModel = JoinTripViewModel()
        viewModel.roomCode = "12a3b4"
        #expect(viewModel.roomCode == "1234")
        #expect(viewModel.isValidCode == false)

        viewModel.roomCode = "ABCDEF"
        #expect(viewModel.roomCode.isEmpty)
        #expect(viewModel.isValidCode == false)

        viewModel.roomCode = "987-654"
        #expect(viewModel.roomCode == "987654")
        #expect(viewModel.isValidCode == true)
    }

    @Test("Validation should succeed only for 6 digits")
    func codeValidation() {
        let viewModel = JoinTripViewModel()

        viewModel.roomCode = "123"
        #expect(viewModel.isValidCode == false)

        viewModel.roomCode = "654321"
        #expect(viewModel.isValidCode == true)
    }

    @Test("Submit code with invalid format (< 6 digits) should fail and set error message")
    func submitInvalidCodeFormat() async {
        let viewModel = JoinTripViewModel()
        viewModel.roomCode = "123"

        let success = await viewModel.submitCode()
        #expect(success == false)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.joinedSession == nil)
    }

    @Test("Submit code when trip does not exist in database should display not found error")
    func submitNonExistentCode() async {
        let service = SampleTrip.Service(status: .lobby)
        let viewModel = JoinTripViewModel(roomCode: "000000", tripService: service)

        let success = await viewModel.submitCode()
        #expect(success == false)
        #expect(viewModel.errorMessage == "No trip found with this code.")
        #expect(viewModel.joinedSession == nil)
    }

    @Test("A late member joins a trip that already started and stays in it, ready for the map (US-02)")
    func submitCodeWhenTripAlreadyBegun() async throws {
        let service = SampleTrip.Service(status: .inTrip, me: UUID())
        let storage = FakeActiveTripStorage()
        let viewModel = JoinTripViewModel(roomCode: SampleTrip.roomCode, tripService: service, storage: storage)

        let success = await viewModel.submitCode()

        #expect(success == true)
        #expect(viewModel.errorMessage == nil)
        let session = try #require(viewModel.joinedSession)
        #expect(session.state.trip.status == .inTrip)
        let state = try await service.FetchTrip(tripID: SampleTrip.tripID)
        #expect(state.participants.contains { $0.id == session.myParticipantID })
        #expect(storage.storedSummary?.status == .inTrip)
    }

    @Test("Submit code when trip has already ended should display already ended error")
    func submitCodeWhenTripEnded() async {
        let service = SampleTrip.Service(status: .ended)
        let viewModel = JoinTripViewModel(roomCode: SampleTrip.roomCode, tripService: service)

        let success = await viewModel.submitCode()
        #expect(success == false)
        #expect(viewModel.errorMessage == "This trip has already ended.")
        #expect(viewModel.joinedSession == nil)
    }

    @Test("Submit code with valid code in lobby should succeed and prepare session for Trip Room")
    func submitValidCodeInLobby() async {
        let service = SampleTrip.Service(status: .lobby)
        let viewModel = JoinTripViewModel(roomCode: SampleTrip.roomCode, tripService: service)

        let success = await viewModel.submitCode()
        #expect(success == true)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.joinedSession != nil)
        #expect(viewModel.joinedSession?.state.trip.status == .lobby)
        #expect(viewModel.joinedSession?.state.trip.roomCode == SampleTrip.roomCode)
    }

    @Test("Editing room code clears any existing error message")
    func editingRoomCodeClearsError() async {
        let viewModel = JoinTripViewModel()
        viewModel.roomCode = "123"
        _ = await viewModel.submitCode()
        #expect(viewModel.errorMessage != nil)

        viewModel.roomCode = "1234"
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Reset should clear all states")
    func resetState() {
        let viewModel = JoinTripViewModel()
        viewModel.roomCode = "123456"
        viewModel.errorMessage = "Error"

        viewModel.reset()
        #expect(viewModel.roomCode.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isSubmitting == false)
        #expect(viewModel.joinedSession == nil)
    }
}
