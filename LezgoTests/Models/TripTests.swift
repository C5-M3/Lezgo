//
//  TripTests.swift
//  LezgoTests
//
//  Created by Oky Faishal on 28/10/26.
//

import Testing
@testable import Lezgo

/// The one room code rule that joining and inviting share (US-03, US-04): six digits, numbers only.
struct TripTests {
    @Test func SixDigitsIsAValidRoomCode() {
        #expect(Trip.IsValidRoomCode("897654"))
    }

    @Test(arguments: ["", "12345", "1234567", "12a456", " 89765", "٨٩٧٦٥٤", "８９７６５４"])
    func OnlySixPlainDigitsAreAValidRoomCode(roomCode: String) {
        #expect(Trip.IsValidRoomCode(roomCode) == false)
    }
}
