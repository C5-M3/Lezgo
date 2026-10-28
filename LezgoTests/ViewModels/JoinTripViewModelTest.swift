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

    @Test("Submit code with invalid code should fail and set error message")
    func submitInvalidCode() async {
        let viewModel = JoinTripViewModel()
        viewModel.roomCode = "123"

        let success = await viewModel.submitCode()
        #expect(success == false)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("Submit code with valid code should succeed")
    func submitValidCode() async {
        let viewModel = JoinTripViewModel()
        viewModel.roomCode = "654321"

        let success = await viewModel.submitCode()
        #expect(success == true)
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
    }
}
