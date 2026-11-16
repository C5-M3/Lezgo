//
//  TripSeatTests.swift
//  LezgoTests
//
//  Created by Oky Faishal on 16/11/26.
//

import Foundation
import Testing
@testable import Lezgo

struct TripSeatTests {
    private let seat = TripSeat(tripID: UUID(), participantID: UUID(), sessionID: UUID())

    @Test func SeatIsThreeIdentifiersInFortyEightBytes() {
        #expect(seat.bytes.count == TripSeat.byteCount)
        #expect(TripSeat.byteCount == 48)
    }

    @Test func SeatSurvivesBeingSavedAsBytes() {
        #expect(TripSeat(bytes: seat.bytes) == seat)
    }

    @Test(arguments: [0, 47, 49, 64])
    func BytesOfAnotherLengthAreNotASeat(length: Int) {
        #expect(TripSeat(bytes: Data(repeating: 7, count: length)) == nil)
    }

    @Test func RecordNameIsTheSameForTheSameAccountEverywhere() {
        #expect(TripSeat.RecordName(forAccount: "_agus0001") == TripSeat.RecordName(forAccount: "_agus0001"))
    }

    @Test func RecordNameDiffersBetweenAccounts() {
        #expect(TripSeat.RecordName(forAccount: "_agus0001") != TripSeat.RecordName(forAccount: "_budi7F3A"))
    }

    @Test func RecordNameDoesNotShowTheAccount() {
        let name = TripSeat.RecordName(forAccount: "_agus0001")

        #expect(name.contains("agus0001") == false)
        #expect(name.hasSuffix("-seat"))
        #expect(name.first != "_")
        #expect(name.allSatisfy { $0.isASCII })
    }

    @Test func AccountTokenIsTheRecordNameWithoutTheSuffix() {
        #expect(TripSeat.RecordName(forAccount: "_agus0001") == TripSeat.AccountToken(forAccount: "_agus0001") + "-seat")
    }
}
