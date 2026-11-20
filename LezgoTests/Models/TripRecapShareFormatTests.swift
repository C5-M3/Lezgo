//
//  TripRecapShareFormatTests.swift
//  LezgoTests
//

import Testing
@testable import Lezgo

struct TripRecapShareFormatTests {
    @Test func FormatsAreInTheOrderTheyAreShown() {
        #expect(TripRecapShareFormat.allCases == [.classic, .routeLine, .mapCenter, .together, .convoy])
    }

    @Test func EveryFormatSavesToItsOwnFile() {
        let suffixes = TripRecapShareFormat.allCases.map(\.fileNameSuffix)

        #expect(Set(suffixes).count == TripRecapShareFormat.allCases.count)
    }

    @Test func ClassicKeepsTheFileNameItAlwaysHad() {
        #expect(TripRecapShareFormat.classic.fileNameSuffix.isEmpty)
    }
}
